// Every test drives the real binary against a temp state tree — the same
// contract production has, with the paths moved.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

var bin string

func TestMain(m *testing.M) {
	dir, err := os.MkdirTemp("", "converge-status-build")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	bin = filepath.Join(dir, "converge-status")
	out, err := exec.Command("go", "build", "-o", bin, ".").CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "building the binary under test: %v\n%s", err, out)
		os.RemoveAll(dir)
		os.Exit(1)
	}
	code := m.Run()
	os.RemoveAll(dir)
	os.Exit(code)
}

type tree struct {
	t          *testing.T
	statusFile string
	rebootDir  string
}

func newTree(t *testing.T) *tree {
	t.Helper()
	root := t.TempDir()
	tr := &tree{
		t:          t,
		statusFile: filepath.Join(root, "cosmo-rebuild", "status"),
		rebootDir:  filepath.Join(root, "reboot-pending"),
	}
	if err := os.MkdirAll(tr.rebootDir, 0o755); err != nil {
		t.Fatal(err)
	}
	return tr
}

func (tr *tree) run(args ...string) (string, string, error) {
	tr.t.Helper()
	cmd := exec.Command(bin, args...)
	var stdout, stderr strings.Builder
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	err := cmd.Run()
	return stdout.String(), stderr.String(), err
}

func (tr *tree) set(args ...string) {
	tr.t.Helper()
	_, stderr, err := tr.run(append([]string{"set", "--status-file", tr.statusFile}, args...)...)
	if err != nil {
		tr.t.Fatalf("set %v: %v\n%s", args, err, stderr)
	}
}

func (tr *tree) render(extra ...string) view {
	tr.t.Helper()
	args := append([]string{"render", "--status-file", tr.statusFile, "--reboot-dir", tr.rebootDir}, extra...)
	stdout, stderr, err := tr.run(args...)
	if err != nil {
		tr.t.Fatalf("render: %v\n%s", err, stderr)
	}
	var v view
	if err := json.Unmarshal([]byte(stdout), &v); err != nil {
		tr.t.Fatalf("render emitted %q: %v", stdout, err)
	}
	return v
}

func (tr *tree) status() Status {
	tr.t.Helper()
	s, err := readStatus(tr.statusFile)
	if err != nil {
		tr.t.Fatalf("reading back the status file: %v", err)
	}
	return s
}

// pending arms the reboot detector's state files the way reboot-needed does.
func (tr *tree) pending(ageDays int, blocked string) {
	tr.t.Helper()
	since := time.Now().Add(-time.Duration(ageDays) * 24 * time.Hour).Unix()
	write(tr.t, filepath.Join(tr.rebootDir, "state"),
		fmt.Sprintf("since=%d\ndiverged=kernel\n", since))
	if blocked != "" {
		write(tr.t, filepath.Join(tr.rebootDir, "last-blocked"),
			fmt.Sprintf("at=%d\nreason=%s\n", since, blocked))
	}
}

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func contains(t *testing.T, haystack, needle string) {
	t.Helper()
	if !strings.Contains(haystack, needle) {
		t.Errorf("expected %q in:\n%s", needle, haystack)
	}
}

const (
	revA = "1a2b3c4d5e6f708192a3b4c5d6e7f80912345678"
	revB = "9f8e7d6c5b4a30291817161514131211100f0e0d"
)

// --- schema round trip -----------------------------------------------------

func TestSetThenRenderBuilding(t *testing.T) {
	tr := newTree(t)
	tr.set("phase=building", "target="+revB, "deployed="+revA)

	if got := tr.status(); got.Phase != "building" || got.Target != revB || got.At == 0 || got.Checked == 0 {
		t.Fatalf("status file did not round trip: %+v", got)
	}

	v := tr.render("--host", "laddie")
	if v.Class != "building" {
		t.Fatalf("class = %q, want building", v.Class)
	}
	contains(t, v.Tooltip, "laddie: converging now")
	contains(t, v.Tooltip, revB)
	contains(t, v.Tooltip, revA)
}

func TestSetRejectsGarbage(t *testing.T) {
	tr := newTree(t)
	for _, args := range [][]string{
		{"phase=exploding"},
		{"target=" + revA},          // no phase
		{"phase=current", "revs=x"}, // unknown key
		{"phase=current", "not-a-kv"},
		{"phase=current", "rev=a\nphase=failed"}, // no smuggling a second record in
	} {
		if _, _, err := tr.run(append([]string{"set", "--status-file", tr.statusFile}, args...)...); err == nil {
			t.Errorf("set %v was accepted", args)
		}
	}
	if _, err := os.Stat(tr.statusFile); !os.IsNotExist(err) {
		t.Errorf("a rejected set still wrote the file")
	}
}

// The hourly no-change run: the phase is re-observed, not re-entered, so the
// age the tooltip shows must not reset while `checked` moves.
func TestRepeatedCurrentKeepsAtAndMovesChecked(t *testing.T) {
	tr := newTree(t)
	tr.set("phase=current", "rev="+revA, "at=1000", "checked=1000")
	tr.set("phase=current", "rev="+revA)

	got := tr.status()
	if got.At != 1000 {
		t.Errorf("at = %d, want the first entry (1000)", got.At)
	}
	if got.Checked <= 1000 {
		t.Errorf("checked = %d, want it moved to now", got.Checked)
	}

	tr.set("phase=current", "rev="+revB)
	if got := tr.status(); got.At == 1000 {
		t.Errorf("a new rev must re-stamp at, got %d", got.At)
	}
}

// --- precedence ------------------------------------------------------------

func TestPrecedence(t *testing.T) {
	now := time.Now().Unix()
	fresh := strconv.FormatInt(now, 10)
	ancient := strconv.FormatInt(now-24*3600, 10)

	cases := []struct {
		name       string
		set        []string
		rebootDays int
		want       string
	}{
		{"a converge running now", []string{"phase=building", "target=" + revB, "deployed=" + revA, "checked=" + fresh}, 0, "building"},
		{"a converge that died", []string{"phase=failed", "target=" + revB, "deployed=" + revA, "checked=" + fresh}, 0, "failed"},
		{"converged and nothing owed", []string{"phase=current", "rev=" + revA, "checked=" + fresh}, 0, "current"},
		{"a pending reboot outranks converged", []string{"phase=current", "rev=" + revA, "checked=" + fresh}, 3, "reboot-pending"},
		{"a week of blocked attempts escalates", []string{"phase=current", "rev=" + revA, "checked=" + fresh}, 9, "reboot-overdue"},
		{"a failure outranks even an overdue reboot", []string{"phase=failed", "target=" + revB, "checked=" + fresh}, 9, "failed"},
		{"a running converge outranks an overdue reboot", []string{"phase=building", "target=" + revB, "checked=" + fresh}, 9, "building"},
		{"a build nobody has touched for a day is silence", []string{"phase=building", "target=" + revB, "checked=" + ancient}, 0, "stale"},
		{"a stale current is silence too", []string{"phase=current", "rev=" + revA, "checked=" + ancient}, 0, "stale"},
		{"a recorded failure does not go stale", []string{"phase=failed", "target=" + revB, "checked=" + ancient}, 0, "failed"},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			tr := newTree(t)
			tr.set(c.set...)
			if c.rebootDays > 0 {
				tr.pending(c.rebootDays, "restic-backups-valley.service is running")
			}
			if got := tr.render().Class; got != c.want {
				t.Fatalf("class = %q, want %q", got, c.want)
			}
		})
	}
}

// The state the whole redesign exists to surface: laddie knows main moved and
// knows it is not running it, with no GitHub round trip anywhere on this path.
func TestFailedWithNewTargetIsTheBehindState(t *testing.T) {
	tr := newTree(t)
	tr.set("phase=failed", "target="+revB, "deployed="+revA,
		"detail=error: builder for '/nix/store/x.drv' failed with exit code 1")

	v := tr.render("--host", "laddie")
	if v.Class != "failed" {
		t.Fatalf("class = %q, want failed", v.Class)
	}
	contains(t, v.Text, revA[:7])
	contains(t, v.Tooltip, "main moved to "+revB[:7])
	contains(t, v.Tooltip, "no longer tracking main")
	contains(t, v.Tooltip, "builder for")

	// Same rev on both sides: the run died without main having moved, so there
	// is nothing to be behind — but it is still a failure.
	tr.set("phase=failed", "target="+revA, "deployed="+revA, "detail=could not resolve refs/heads/main")
	v = tr.render()
	if v.Class != "failed" {
		t.Fatalf("class = %q, want failed", v.Class)
	}
	if strings.Contains(v.Tooltip, "main moved to") {
		t.Errorf("claimed the host is behind when it is not:\n%s", v.Tooltip)
	}
}

func TestStaleWhenNothingHasEverRun(t *testing.T) {
	tr := newTree(t)
	v := tr.render("--host", "laddie")
	if v.Class != "stale" {
		t.Fatalf("class = %q, want stale", v.Class)
	}
	contains(t, v.Tooltip, "no word from the rebuild machinery")
	contains(t, v.Tooltip, tr.statusFile)

	// Unparseable junk is the same absence of information, not a phase.
	write(t, tr.statusFile, "}}} not a status file\n")
	if got := tr.render().Class; got != "stale" {
		t.Fatalf("class = %q for an unreadable status file, want stale", got)
	}
}

func TestTooltipCarriesRebootAgeAndBlocker(t *testing.T) {
	tr := newTree(t)
	tr.set("phase=current", "rev="+revA)
	tr.pending(3, "klaus run 20260825-0732-99333f00 in progress")

	v := tr.render()
	contains(t, v.Tooltip, "reboot pending since 3 days")
	contains(t, v.Tooltip, "klaus run 20260825-0732-99333f00 in progress")
	contains(t, v.Text, revA[:7])

	// The window between first detection and that night's attempt.
	os.Remove(filepath.Join(tr.rebootDir, "last-blocked"))
	contains(t, tr.render().Tooltip, "none recorded")
}

// --- the ExecStopPost guard ------------------------------------------------

func TestUnlessTerminal(t *testing.T) {
	tr := newTree(t)

	// The shape ExecStopPost sees after a run that died mid-build: the phase is
	// still `building`, so systemd's account of the death is what lands — and
	// it inherits the revs the run announced.
	tr.set("phase=building", "target="+revB, "deployed="+revA)
	tr.set("--unless-terminal", "phase=failed", "detail=exit-code (status 1)")
	got := tr.status()
	if got.Phase != "failed" || got.Target != revB || got.Deployed != revA {
		t.Fatalf("ExecStopPost failure did not inherit the run's revs: %+v", got)
	}

	// A script that recorded its own outcome keeps it: systemd's "exit-code"
	// is strictly less informative than "could not resolve refs/heads/main".
	tr.set("phase=failed", "target="+revB, "deployed="+revA, "detail=could not resolve refs/heads/main on the remote")
	tr.set("--unless-terminal", "phase=failed", "detail=exit-code (status 1)")
	if got := tr.status().Detail; got != "could not resolve refs/heads/main on the remote" {
		t.Errorf("detail = %q, want the script's own", got)
	}

	// And the success path, where ExecStopPost runs too and must do nothing.
	tr.set("phase=current", "rev="+revB)
	tr.set("--unless-terminal", "phase=failed", "detail=exit-code (status 1)")
	if got := tr.status().Phase; got != "current" {
		t.Errorf("phase = %q after a successful run, want current", got)
	}
}

// --- watch -----------------------------------------------------------------

func TestWatchStreamsOnEachTransition(t *testing.T) {
	tr := newTree(t)
	tr.set("phase=current", "rev="+revA)

	cmd := exec.Command(bin, "watch",
		"--status-file", tr.statusFile, "--reboot-dir", tr.rebootDir,
		"--period", "1h", "--host", "laddie")
	// The stdin production hands it: waybar's systemd user unit gets
	// StandardInput=null and ssh forwards that EOF straight through. A watch
	// that treated it as a hangup would end every stream on arrival.
	devnull, err := os.Open(os.DevNull)
	if err != nil {
		t.Fatal(err)
	}
	defer devnull.Close()
	cmd.Stdin = devnull
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cmd.Process.Kill() })

	lines := make(chan view, 8)
	go func() {
		sc := bufio.NewScanner(stdout)
		for sc.Scan() {
			var v view
			if json.Unmarshal(sc.Bytes(), &v) == nil {
				lines <- v
			}
		}
		close(lines)
	}()

	next := func(what string) view {
		t.Helper()
		select {
		case v, ok := <-lines:
			if !ok {
				t.Fatalf("watch closed its stream waiting for %s", what)
			}
			return v
		case <-time.After(10 * time.Second):
			t.Fatalf("no line for %s", what)
			return view{}
		}
	}

	if v := next("the initial render"); v.Class != "current" {
		t.Fatalf("first line class = %q, want current", v.Class)
	}

	// A transition authored the way the converge unit authors it — tmp+mv into
	// a directory the watch is holding, not a write to the file it opened.
	tr.set("phase=building", "target="+revB, "deployed="+revA)
	if v := next("the building transition"); v.Class != "building" {
		t.Fatalf("class after set = %q, want building", v.Class)
	}

	// The other directory: the reboot detector's verdict, which must reach the
	// bar without the converge unit doing anything at all.
	tr.set("phase=current", "rev="+revB)
	if v := next("the return to current"); v.Class != "current" {
		t.Fatalf("class = %q, want current", v.Class)
	}
	tr.pending(2, "session 2 (tty1) idle under 60m")
	if v := next("the reboot verdict"); v.Class != "reboot-pending" {
		t.Fatalf("class after the detector wrote its state = %q, want reboot-pending", v.Class)
	}

	// A dropped ssh reaches the watch as a closed stdout: the next line it tries
	// to write is what ends it, so a session that went away leaves no watcher
	// behind past the next transition or tick.
	stdout.Close()
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	tr.set("phase=current", "rev="+revA)
	select {
	case <-done:
	case <-time.After(10 * time.Second):
		cmd.Process.Kill()
		t.Fatal("watch outlived the stdout a dropped ssh would have closed")
	}
}

// The whole stream, in the shape production runs it: one process, no stdin,
// still emitting after the far end of the bar has been up for a while. This is
// the regression the reconnect loop cannot paper over — a watch that exits on
// arrival turns the widget into an ssh hammer.
func TestWatchOutlivesAnEmptyStdin(t *testing.T) {
	tr := newTree(t)
	tr.set("phase=current", "rev="+revA)

	devnull, err := os.Open(os.DevNull)
	if err != nil {
		t.Fatal(err)
	}
	defer devnull.Close()

	cmd := exec.Command(bin, "watch",
		"--status-file", tr.statusFile, "--reboot-dir", tr.rebootDir, "--period", "1h")
	cmd.Stdin = devnull
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cmd.Process.Kill() })

	sc := bufio.NewScanner(stdout)
	if !sc.Scan() {
		t.Fatal("no initial line")
	}
	// Long enough that an exit-on-EOF would already have happened; the
	// transition below is what proves the watcher is still armed, since a dead
	// process ends the scan rather than answering it.
	time.Sleep(500 * time.Millisecond)
	tr.set("phase=building", "target="+revB, "deployed="+revA)
	got := make(chan string, 1)
	go func() {
		if sc.Scan() {
			got <- sc.Text()
		}
		close(got)
	}()
	select {
	case line, ok := <-got:
		if !ok {
			t.Fatal("watch stopped streaming after the initial render")
		}
		var v view
		if err := json.Unmarshal([]byte(line), &v); err != nil || v.Class != "building" {
			t.Fatalf("line after the transition = %q", line)
		}
	case <-time.After(10 * time.Second):
		t.Fatal("no line for the transition")
	}
}

// waybar's format-alt switches on `alt`, so it has to carry the state too.
func TestAltMirrorsClass(t *testing.T) {
	tr := newTree(t)
	tr.set("phase=building", "target="+revB)
	if v := tr.render(); v.Alt != v.Class || v.Alt == "" {
		t.Fatalf("alt = %q, class = %q", v.Alt, v.Class)
	}
}

// --- what the rev is -------------------------------------------------------

// Metadata describes one rev — the target while building, the deployed rev
// once current — so it must not follow the other one onto its line.
func TestDateAndSubjectLandOnTheRevTheyDescribe(t *testing.T) {
	tr := newTree(t)
	when := time.Date(2026, 9, 4, 16, 50, 0, 0, time.Local)
	stamp := "committed=" + strconv.FormatInt(when.Unix(), 10)

	tr.set("phase=building", "target="+revB, "deployed="+revA,
		"subject=flake.lock: Update (#795)", stamp)
	v := tr.render("--host", "laddie")
	if got := tooltipLine(t, v.Tooltip, "target"); got != "target    "+revB+"  2026-09-04 16:50  flake.lock: Update (#795)" {
		t.Errorf("target line = %q", got)
	}
	if got := tooltipLine(t, v.Tooltip, "deployed"); got != "deployed  "+revA {
		t.Errorf("deployed line = %q, want the sha alone: the metadata is the target's", got)
	}

	// Once switched, the same rev is the deployed one and the line moves with it.
	tr.set("phase=current", "rev="+revB, "subject=flake.lock: Update (#795)", stamp)
	v = tr.render("--host", "laddie")
	if got := tooltipLine(t, v.Tooltip, "deployed"); got != "deployed  "+revB+"  2026-09-04 16:50  flake.lock: Update (#795)" {
		t.Errorf("deployed line = %q", got)
	}
	contains(t, v.Text, revB[:7]) // the bar text is still icon + short rev, nothing more

	// And on the line that says the host is behind.
	tr.set("phase=failed", "target="+revB, "deployed="+revA, "detail=exit-code",
		"subject=flake.lock: Update (#795)", stamp)
	v = tr.render("--host", "laddie")
	contains(t, v.Tooltip, "main moved to "+revB[:7]+" and this host is not on it  2026-09-04 16:50  flake.lock: Update (#795)")
	if got := tooltipLine(t, v.Tooltip, "deployed"); got != "deployed  "+revA {
		t.Errorf("deployed line = %q, want the sha alone", got)
	}
}

// The mirror lookup is best effort, so `set` is called without metadata often:
// on the hourly re-observation, and from ExecStopPost, which knows nothing but
// that the unit died. Neither may blank out what the run already recorded.
func TestMetadataCarriesForwardOverTheSameRev(t *testing.T) {
	tr := newTree(t)
	tr.set("phase=current", "rev="+revA, "subject=identities: sign work commits", "committed=1757000000")
	tr.set("phase=current", "rev="+revA)
	if got := tr.status(); got.Subject != "identities: sign work commits" || got.Committed != 1757000000 {
		t.Errorf("a re-observed current dropped what it knew: %+v", got)
	}

	// ExecStopPost inherits the target first, then that target's metadata.
	tr.set("phase=building", "target="+revB, "deployed="+revA, "subject=flake.lock: Update", "committed=1757000001")
	tr.set("--unless-terminal", "phase=failed", "detail=exit-code (status 1)")
	if got := tr.status(); got.Target != revB || got.Subject != "flake.lock: Update" || got.Committed != 1757000001 {
		t.Errorf("the failure did not describe the target it inherited: %+v", got)
	}

	// A different rev is a different commit, and the file is one record rather
	// than a history: there is nothing to inherit and nothing stale to keep.
	tr.set("phase=current", "rev="+revA)
	if got := tr.status(); got.Subject != "" || got.Committed != 0 {
		t.Errorf("metadata followed a rev change: %+v", got)
	}
}

// git subjects are one line by construction, but the tooltip is not the place
// to find out otherwise — and a long one would drag the bar's window wide.
func TestSubjectIsFlattenedAndCapped(t *testing.T) {
	tr := newTree(t)
	tr.set("phase=current", "rev="+revA, "subject=fix:\tthe\vthing   spaced   out")
	if got := tr.status().Subject; got != "fix: the thing spaced out" {
		t.Errorf("subject = %q", got)
	}

	tr.set("phase=current", "rev="+revB, "subject="+strings.Repeat("x", 300))
	if got := tr.status().Subject; len([]rune(got)) != 121 || !strings.HasSuffix(got, "…") {
		t.Errorf("subject was not capped to 120 and an ellipsis: %q", got)
	}

	// A newline is a second record trying to get in, not a subject.
	if _, _, err := tr.run("set", "--status-file", tr.statusFile,
		"phase=current", "rev="+revA, "subject=x\nphase=failed"); err == nil {
		t.Error("a subject spanning lines was accepted")
	}
}

// A host whose script has not learned to look the metadata up writes none, and
// its tooltip has to keep reading exactly as it did.
func TestRenderWithoutMetadataIsUnchanged(t *testing.T) {
	tr := newTree(t)
	then := strconv.FormatInt(time.Now().Unix()-600, 10)
	tr.set("phase=current", "rev="+revA, "at="+then, "checked="+then)

	want := "laddie: converged with main\ndeployed  " + revA +
		"\nverified against the remote 10 minutes ago"
	if got := tr.render("--host", "laddie").Tooltip; got != want {
		t.Errorf("tooltip =\n%s\nwant\n%s", got, want)
	}
}

// The tooltip line starting with the given word, for asserting what is — and
// what is not — appended to it.
func tooltipLine(t *testing.T, tooltip, prefix string) string {
	t.Helper()
	for _, line := range strings.Split(tooltip, "\n") {
		if strings.HasPrefix(line, prefix) {
			return line
		}
	}
	t.Fatalf("no line starting %q in:\n%s", prefix, tooltip)
	return ""
}
