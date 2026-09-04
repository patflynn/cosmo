package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// One waybar custom-module line. `alt` mirrors `class` so a format-alt config
// can reach the state too.
type view struct {
	Text    string `json:"text"`
	Tooltip string `json:"tooltip"`
	Class   string `json:"class"`
	Alt     string `json:"alt"`
}

// What the reboot detector left behind. Read straight from its files rather
// than re-derived: the split it found is not visible from here.
type rebootState struct {
	since   int64
	blocked string
}

func readRebootState(dir string) rebootState {
	var r rebootState
	if v := firstValue(filepath.Join(dir, "state"), "since"); v != "" {
		r.since, _ = strconv.ParseInt(v, 10, 64)
	}
	r.blocked = oneLine(firstValue(filepath.Join(dir, "last-blocked"), "reason"), 120)
	return r
}

func firstValue(path, key string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(b), "\n") {
		if v, ok := strings.CutPrefix(line, key+"="); ok {
			return v
		}
	}
	return ""
}

func render(v viewFlags, now time.Time) view {
	st, stErr := readStatus(v.statusFile)
	reboot := readRebootState(v.rebootDir)
	out := derive(v, st, stErr, reboot, now.Unix())
	out.Alt = out.Class
	return out
}

// Precedence: building > failed > reboot-overdue > reboot-pending > current,
// with stale underneath.
//
// Activity first — a converge running right now is the answer regardless of
// what the last one did. Failure next, because a host that stopped tracking
// main is a bigger fact than a reboot it owes: `failed` with target != deployed
// IS the behind state, and it is the one nobody notices on their own.
//
// The reboot states outrank `current` because `current` cannot see them: the
// switch that authored it is exactly what left the booted kernel and PID 1
// behind, so "converged with main" is true and misleading about a machine one
// reboot short of running it.
//
// Staleness demotes building and current but never failed: a status file
// nobody has touched for hours means the converge unit is not running, and a
// build that claims to still be building past its own TimeoutStartSec is that
// same silence wearing the last phase it managed to write. A recorded failure
// stays a failure however long it sits.
func derive(v viewFlags, st Status, stErr error, reboot rebootState, now int64) view {
	host := v.hostname()
	stale := stErr != nil || st.Phase == "" || st.Checked == 0 ||
		now-st.Checked > int64(v.staleAfter.Seconds())

	deployedLine := func(rev string) string { return "deployed  " + orNone(rev) + st.meta(rev) }

	switch {
	case !stale && st.Phase == phaseBuilding:
		return view{
			Text:  "󰑓 rebuilding",
			Class: "building",
			Tooltip: lines(
				host+": converging now",
				"target    "+orNone(st.Target)+st.meta(st.Target),
				deployedLine(st.Deployed),
				"started "+ago(now, st.At),
			),
		}

	case st.Phase == phaseFailed:
		behind := ""
		if st.Target != "" && st.Target != st.Deployed {
			behind = "main moved to " + short(st.Target) + " and this host is not on it" + st.meta(st.Target)
		}
		return view{
			Text:  "󰀦 " + orQuery(short(st.Deployed)),
			Class: "failed",
			Tooltip: lines(
				host+": cosmo-rebuild FAILED "+ago(now, st.At)+" — no longer tracking main",
				behind,
				"target    "+orNone(st.Target)+st.meta(st.Target),
				deployedLine(st.Deployed),
				orDefault(st.Detail, "(no detail recorded)"),
			),
		}
	}

	if reboot.since > 0 {
		age := now - reboot.since
		if age < 0 {
			age = 0
		}
		head := fmt.Sprintf("%s: reboot pending since %s, last attempt blocked: %s",
			host, relativeAge(age), orDefault(reboot.blocked, "none recorded"))
		text := "󰜉 " + orQuery(short(revOf(st)))
		if age >= int64(v.rebootOverdue.Seconds()) {
			return view{
				Text:    text,
				Class:   "reboot-overdue",
				Tooltip: lines(head, "Every quiet window for over a week has found something running.", deployedLine(revOf(st))),
			}
		}
		return view{
			Text:    text,
			Class:   "reboot-pending",
			Tooltip: lines(head, deployedLine(revOf(st))),
		}
	}

	if !stale && st.Phase == phaseCurrent {
		return view{
			Text:  "󰄬 " + orQuery(short(st.Rev)),
			Class: "current",
			Tooltip: lines(
				host+": converged with main",
				deployedLine(st.Rev),
				"verified against the remote "+ago(now, st.Checked),
			),
		}
	}

	// Nothing is authoring state. Either the converge unit and its hourly timer
	// are both gone, or nothing has ever run here — the one reading that says
	// the machinery itself is the problem, not what it found.
	last := "no status file at " + v.statusFile
	if stErr == nil && st.Phase != "" {
		last = "last wrote " + st.Phase + " " + ago(now, st.Checked)
	}
	return view{
		Text:    "󰚰 ?",
		Class:   "stale",
		Tooltip: lines(host+": no word from the rebuild machinery", last, deployedLine(revOf(st))),
	}
}

// The commit date and subject the machinery recorded, as a suffix — for the
// rev identity() names and no other, since that is the only one they describe.
// Empty when it has neither, so every other line (and a status file written
// before this existed) renders exactly as it did.
func (s Status) meta(rev string) string {
	if rev == "" || rev != s.identity() {
		return ""
	}
	out := ""
	if s.Committed != 0 {
		out += "  " + time.Unix(s.Committed, 0).Format("2006-01-02 15:04")
	}
	if s.Subject != "" {
		out += "  " + s.Subject
	}
	return out
}

// The rev the host is actually running, whichever phase recorded it.
func revOf(st Status) string {
	if st.Rev != "" {
		return st.Rev
	}
	return st.Deployed
}

func short(rev string) string {
	if len(rev) > 7 {
		return rev[:7]
	}
	return rev
}

func orNone(s string) string { return orDefault(s, "<none>") }

func orQuery(s string) string { return orDefault(s, "?") }

func orDefault(s, def string) string {
	if s == "" {
		return def
	}
	return s
}

// Skips empty parts, so a tooltip can carry an optional line without growing a
// blank one when it is absent.
func lines(parts ...string) string {
	out := parts[:0]
	for _, p := range parts {
		if p != "" {
			out = append(out, p)
		}
	}
	return strings.Join(out, "\n")
}

func ago(now, then int64) string {
	if then == 0 {
		return "at an unknown time"
	}
	d := now - then
	if d < 0 {
		d = 0
	}
	return relativeAge(d) + " ago"
}

// Coarse on purpose: "6 days" is the whole message, and an exact figure would
// only invite reading precision into a nightly retry.
func relativeAge(secs int64) string {
	var n int64
	var unit string
	switch {
	case secs < 5400:
		n, unit = secs/60, "minute"
	case secs < 172800:
		n, unit = secs/3600, "hour"
	default:
		n, unit = secs/86400, "day"
	}
	if n != 1 {
		unit += "s"
	}
	return fmt.Sprintf("%d %s", n, unit)
}

func emit(w io.Writer, v view) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(w, "%s\n", b)
	return err
}

func cmdRender(args []string, stdout, stderr io.Writer) error {
	fs := flag.NewFlagSet("render", flag.ContinueOnError)
	fs.SetOutput(stderr)
	var v viewFlags
	v.bind(fs)
	if err := fs.Parse(args); err != nil {
		return err
	}
	return emit(stdout, render(v, time.Now()))
}
