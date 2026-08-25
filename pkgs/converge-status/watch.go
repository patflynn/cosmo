package main

import (
	"flag"
	"io"
	"path/filepath"
	"time"

	"github.com/fsnotify/fsnotify"
)

// Directories are watched, not files: every writer here replaces its file with
// tmp+mv, which detaches the inode a file watch would be holding.
func watchDirs(v viewFlags) []string {
	return []string{filepath.Dir(v.statusFile), v.rebootDir}
}

func interesting(v viewFlags, name string) bool {
	switch filepath.Base(name) {
	case filepath.Base(v.statusFile), "state", "last-blocked":
		return true
	}
	return false
}

func cmdWatch(args []string, stdout, stderr io.Writer) error {
	fs := flag.NewFlagSet("watch", flag.ContinueOnError)
	fs.SetOutput(stderr)
	var v viewFlags
	v.bind(fs)
	period := fs.Duration("period", defaultWatchPeriod, "re-render this often even when nothing changed")
	if err := fs.Parse(args); err != nil {
		return err
	}

	w, err := fsnotify.NewWatcher()
	if err != nil {
		return err
	}
	defer w.Close()

	// A state dir that does not exist yet is not an error — the machinery has
	// simply never run. Adds are retried on every tick until they take.
	watched := map[string]bool{}
	addWatches := func() {
		for _, d := range watchDirs(v) {
			if watched[d] {
				continue
			}
			if w.Add(d) == nil {
				watched[d] = true
			}
		}
	}
	addWatches()

	if err := emit(stdout, render(v, time.Now())); err != nil {
		return err
	}

	// Nothing watches stdin: waybar runs its modules from a systemd user unit,
	// so ssh forwards an immediate EOF and a hangup read there would end every
	// stream in the millisecond it started. What ends this instead is the write
	// below failing — sshd tears the session down when the connection goes, and
	// a write to a closed stdout takes the process with it (Go raises SIGPIPE
	// on fd 1). The tick is therefore also the leak bound: a watcher whose far
	// end vanished lives at most one period.
	ticker := time.NewTicker(*period)
	defer ticker.Stop()

	// Coalesces the burst a tmp+mv makes (create, write, chmod, rename) into
	// the one line those four events are collectively worth.
	var settle <-chan time.Time
	for {
		select {
		case ev, ok := <-w.Events:
			if !ok {
				return nil
			}
			if interesting(v, ev.Name) && settle == nil {
				settle = time.After(100 * time.Millisecond)
			}
		case <-w.Errors:
			// Watch errors are transient (queue overflow, a dir replaced);
			// the tick below re-renders and re-adds regardless.
		case <-settle:
			settle = nil
			if err := emit(stdout, render(v, time.Now())); err != nil {
				return err
			}
		case <-ticker.C:
			addWatches()
			// Unconditional: this line is both the tooltip ages staying honest
			// and the proof to the far end that the stream is still alive.
			if err := emit(stdout, render(v, time.Now())); err != nil {
				return err
			}
		}
	}
}
