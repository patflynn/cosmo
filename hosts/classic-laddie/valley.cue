// The valley host declaration for classic-laddie — what this host serves,
// validated at build time against the-valley's schema (schema/valley.cue in
// github:gunk-dev/the-valley) by the valley-host NixOS module. This file is
// the single domain input: projects and their push mirrors are declared
// here, never as Nix options.
//
// Validate by hand (from a the-valley checkout):
//   cue vet -c <the-valley>/schema/valley.cue hosts/classic-laddie/valley.cue
package valley

projects: {
	// The Phase 0 pilot repo (the-valley roadmap, oc-9949561). GitHub is
	// retained as a transitional push mirror during the migration: every
	// push to the primary is replicated there, best-effort. The Hetzner
	// VPS mirror URL is added here once that host is provisioned (see
	// the-valley decision dcr-db1acbb).
	"the-valley": {
		mirrors: ["git@github.com:gunk-dev/the-valley.git"]
	}
}

// The host's durability policy (the-valley's #Backup): nightly restic to
// the Hetzner Storage Box over sftp, retention 7 daily / 4 weekly / 6
// monthly — all the schema defaults, so only the target is spelled out.
// The policy lives here now; the repository URL, credentials, and host-key
// pin are machine integration, supplied in default.nix
// (services.valley.backup.*) alongside the enablement runbook.
backup: {
	target: "restic-sftp"
}
