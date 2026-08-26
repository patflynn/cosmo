// converge-status: the rebuild machinery's own account of itself.
//
// `set` is called by cosmo-rebuild at each transition, `render` turns the
// resulting file (plus the reboot detector's) into one waybar JSON line, and
// `watch` streams that line whenever either changes. Nothing here reaches the
// network: the widget's whole picture comes from files the machinery wrote.
package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"time"
)

const (
	defaultStatusFile = "/var/lib/cosmo-rebuild/status"
	defaultRebootDir  = "/var/lib/reboot-pending"
	// A week of nightly attempts, all blocked: the machine is trying and
	// failing to find a quiet moment, and that is the operator's problem.
	defaultRebootOverdue = 7 * 24 * time.Hour
	// Three missed hourly converge ticks. Below that a quiet status file is
	// just a machine with nothing to say; above it, the machinery is down.
	defaultStaleAfter = 3 * time.Hour
	// Long enough that the bar is not a spinner, short enough that a tooltip
	// reading "4 minutes ago" is never off by more than one step.
	defaultWatchPeriod = 5 * time.Minute
)

const usage = `usage:
  converge-status set [flags] phase=<building|current|failed> [key=value ...]
  converge-status render [flags]
  converge-status watch [flags]

Flags precede the key=value arguments. Run a subcommand with -h for its flags.`

func main() {
	if err := run(os.Args[1:], os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, "converge-status:", err)
		os.Exit(1)
	}
}

func run(args []string, stdout, stderr io.Writer) error {
	if len(args) == 0 {
		fmt.Fprintln(stderr, usage)
		return fmt.Errorf("no subcommand")
	}
	switch args[0] {
	case "set":
		return cmdSet(args[1:], stderr)
	case "render":
		return cmdRender(args[1:], stdout, stderr)
	case "watch":
		return cmdWatch(args[1:], stdout, stderr)
	case "-h", "--help", "help":
		fmt.Fprintln(stdout, usage)
		return nil
	default:
		fmt.Fprintln(stderr, usage)
		return fmt.Errorf("unknown subcommand %q", args[0])
	}
}

// Shared by render and watch; every path and threshold is a flag so a test can
// point the binary at a temp tree, the same seam auto-reboot-scripts.nix takes
// from the environment.
type viewFlags struct {
	statusFile    string
	rebootDir     string
	host          string
	rebootOverdue time.Duration
	staleAfter    time.Duration
}

func (v *viewFlags) bind(fs *flag.FlagSet) {
	fs.StringVar(&v.statusFile, "status-file", defaultStatusFile, "status file cosmo-rebuild authors")
	fs.StringVar(&v.rebootDir, "reboot-dir", defaultRebootDir, "directory the reboot detector writes state/last-blocked into")
	fs.StringVar(&v.host, "host", "", "name to label the tooltip with (default: this machine's hostname)")
	fs.DurationVar(&v.rebootOverdue, "reboot-overdue", defaultRebootOverdue, "a reboot pending this long escalates")
	fs.DurationVar(&v.staleAfter, "stale-after", defaultStaleAfter, "a status file untouched this long means the machinery is not running")
}

func (v *viewFlags) hostname() string {
	if v.host != "" {
		return v.host
	}
	if h, err := os.Hostname(); err == nil && h != "" {
		return h
	}
	return "host"
}
