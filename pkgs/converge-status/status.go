package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"unicode"
)

// Phases are the only thing the bar switches on, so the set is closed and
// `set` rejects anything outside it rather than letting a typo reach the file.
const (
	phaseBuilding = "building"
	phaseCurrent  = "current"
	phaseFailed   = "failed"
)

// Status is the file at $STATE_DIRECTORY/status, one key=value per line — the
// same idiom as /var/lib/reboot-pending/state.
//
//	phase=building  target=<rev> deployed=<prev>   a run announced a deploy
//	phase=current   rev=<rev>                      the last switch succeeded
//	phase=failed    target=<rev> deployed=<prev>   the run died; deployed is
//	                                               what the host is still on
//
// at        when the phase (with this target/rev) was first entered
// checked   when the machinery last wrote anything — the liveness clock
// detail    one line of why, for failures
// subject   the rev identity() names — its one-line commit subject, and
// committed its commit date. Never the other rev on the line below it.
type Status struct {
	Phase     string
	Target    string
	Deployed  string
	Rev       string
	Detail    string
	Subject   string
	At        int64
	Checked   int64
	Committed int64
}

// What distinguishes one occurrence of a phase from the next. Equal identity
// means the same situation persisting, which is what carries `at` forward.
func (s Status) identity() string {
	if s.Phase == phaseCurrent {
		return s.Rev
	}
	return s.Target
}

func (s Status) terminal() bool { return s.Phase == phaseCurrent || s.Phase == phaseFailed }

func parseStatus(r io.Reader) Status {
	var s Status
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		k, v, ok := strings.Cut(sc.Text(), "=")
		if !ok {
			continue
		}
		// Unknown keys are ignored, not rejected: a newer writer's file must
		// stay readable by an older renderer during a partial deploy.
		_ = assign(&s, strings.TrimSpace(k), v)
	}
	return s
}

func assign(s *Status, key, value string) error {
	switch key {
	case "phase":
		s.Phase = value
	case "target":
		s.Target = value
	case "deployed":
		s.Deployed = value
	case "rev":
		s.Rev = value
	case "detail":
		s.Detail = value
	case "subject":
		s.Subject = value
	case "committed":
		s.Committed, _ = strconv.ParseInt(value, 10, 64)
	case "at":
		s.At, _ = strconv.ParseInt(value, 10, 64)
	case "checked":
		s.Checked, _ = strconv.ParseInt(value, 10, 64)
	default:
		return fmt.Errorf("unknown key %q", key)
	}
	return nil
}

func readStatus(path string) (Status, error) {
	f, err := os.Open(path)
	if err != nil {
		return Status{}, err
	}
	defer f.Close()
	return parseStatus(f), nil
}

func (s Status) write(path string) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	var b strings.Builder
	for _, kv := range []struct {
		k, v string
	}{
		{"phase", s.Phase},
		{"rev", s.Rev},
		{"target", s.Target},
		{"deployed", s.Deployed},
		{"at", intOrEmpty(s.At)},
		{"checked", intOrEmpty(s.Checked)},
		{"committed", intOrEmpty(s.Committed)},
		{"detail", s.Detail},
		{"subject", s.Subject},
	} {
		if kv.v != "" {
			fmt.Fprintf(&b, "%s=%s\n", kv.k, kv.v)
		}
	}

	// tmp+mv, so a reader (or the inotify watch) never sees half a record.
	// 0644 because the waybar side reads this as an unprivileged user.
	tmp, err := os.CreateTemp(dir, ".status-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.WriteString(b.String()); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(0o644); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), path)
}

func intOrEmpty(v int64) string {
	if v == 0 {
		return ""
	}
	return strconv.FormatInt(v, 10)
}

func cmdSet(args []string, stderr io.Writer) error {
	fs := flag.NewFlagSet("set", flag.ContinueOnError)
	fs.SetOutput(stderr)
	statusFile := fs.String("status-file", defaultStatusFile, "status file to author")
	// The ExecStopPost guard: a run whose script already recorded how it ended
	// must not have that overwritten by systemd's coarser account of it.
	unlessTerminal := fs.Bool("unless-terminal", false, "do nothing if the recorded phase is already current or failed")
	if err := fs.Parse(args); err != nil {
		return err
	}

	var next Status
	sawPhase := false
	for _, arg := range fs.Args() {
		k, v, ok := strings.Cut(arg, "=")
		if !ok {
			return fmt.Errorf("argument %q is not key=value", arg)
		}
		if strings.ContainsAny(v, "\n\r") {
			return fmt.Errorf("value for %q spans lines", k)
		}
		if k == "detail" {
			v = oneLine(v, 200)
		}
		if k == "subject" {
			v = oneLine(v, 120)
		}
		if err := assign(&next, k, v); err != nil {
			return err
		}
		if k == "phase" {
			sawPhase = true
		}
	}
	if !sawPhase {
		return fmt.Errorf("no phase= given")
	}
	switch next.Phase {
	case phaseBuilding, phaseCurrent, phaseFailed:
	default:
		return fmt.Errorf("unknown phase %q", next.Phase)
	}

	prev, prevErr := readStatus(*statusFile)
	if *unlessTerminal && prevErr == nil && prev.terminal() {
		return nil
	}

	now := time.Now().Unix()
	// First entry wins, the same rule reboot-needed applies to `since=`: what
	// the bar ages is how long this situation has held, not how long since the
	// last tick that re-observed it.
	if next.At == 0 {
		if prevErr == nil && prev.Phase == next.Phase && prev.identity() == next.identity() && prev.At != 0 {
			next.At = prev.At
		} else {
			next.At = now
		}
	}
	if next.Checked == 0 {
		next.Checked = now
	}
	// A failure authored from ExecStopPost knows only that the unit died, so it
	// inherits the revs the run announced when it started building.
	if next.Phase == phaseFailed && prevErr == nil {
		if next.Target == "" {
			next.Target = prev.Target
		}
		if next.Deployed == "" {
			next.Deployed = prev.Deployed
		}
	}
	// After that inheritance, so a failure authored from ExecStopPost describes
	// the target it just adopted. Same rev named, same commit: a re-observation
	// or a mirror lookup that came back empty keeps what we already knew.
	if prevErr == nil && prev.identity() == next.identity() {
		if next.Subject == "" {
			next.Subject = prev.Subject
		}
		if next.Committed == 0 {
			next.Committed = prev.Committed
		}
	}
	return next.write(*statusFile)
}

// Journal lines and systemd result strings both end up here; nix build output
// runs to hundreds of characters and a tooltip that wide is worse than none.
func oneLine(s string, max int) string {
	s = strings.TrimSpace(strings.Map(func(r rune) rune {
		if unicode.IsControl(r) {
			return ' '
		}
		return r
	}, s))
	s = strings.Join(strings.Fields(s), " ")
	if r := []rune(s); len(r) > max {
		s = string(r[:max]) + "…"
	}
	return s
}
