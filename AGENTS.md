# Repository guide for coding agents

This repository is the NixOS configuration for Igor's machines. It is a
personal configuration, not a fleet framework.

This root file is the one canonical set of agent instructions. It deliberately
uses the tool-neutral `AGENTS.md` convention and does not depend on
vendor-specific per-agent files or nested-file discovery.

## Layout

- `README.md`: installation, Secure Boot, and TPM unlock procedures.
- `flake.nix`: locked inputs, shared module composition, one entry in
  `nixosConfigurations` per machine, and the Disko app used to partition a
  disk during installation.
- `configuration.nix`: machine-wide configuration, and every installed
  package.
- `home.nix`: per-user configuration (Home Manager).
- `plasma.nix`: hand-written Plasma configuration (plasma-manager).
- `plasma-generated.nix`: Plasma configuration captured by `rc2nix`. Never
  edit it; the `config-sync` alias overwrites the whole file.
- `hosts/<name>/`: hostname, install disk, and generated hardware scan.
- `modules/`: shared storage and boot concerns.

## Design rules

1. Nix files describe the computers. Keep them focused on the desired
   installed system: no CI checks, test derivations, formatter outputs,
   development shells, or test-only workarounds.
2. Track as much as the tooling allows. If a setting can be expressed as a
   NixOS or Home Manager option, declare it there rather than leaving it to a
   GUI, a mutable dotfile, or a vendor's own sync service. Plasma settings are
   captured by `rc2nix` into `plasma-generated.nix`; the keys it deliberately
   drops, such as `LookAndFeelPackage`, `ColorScheme` and `Theme`, have to be
   declared by hand in `plasma.nix` or they stay untracked. When an option
   genuinely does not exist, say so explicitly instead of quietly leaving a
   setting untracked.
3. Packages are installed system-wide in `configuration.nix`; their
   configuration is per-user in `home.nix`. Where a Home Manager module would
   install a second copy of a system package, set `package = null` so it only
   writes configuration.
4. Optimize for a first-time reader. Prefer direct declarations and
   descriptive names over abstractions.
5. Comment only what the code cannot say, and default to not commenting. A
   comment earns its place when it records a constraint imposed by hardware or
   an upstream package, warns about a cost, or stops a later reader from
   "fixing" something that is deliberate. Never restate an option name, explain
   what a package does, justify an obvious choice, or point at another file in
   this repository. Prefer one clause at the end of the line over a paragraph
   above it. When unsure, leave it out.
6. Prefer ordinary NixOS options. Introduce a custom option only when it is
   the clean interface between genuinely separate modules, the way
   `nixos-config.storage.installDisk` sits between a host and the shared disk
   layout.
7. Keep Disko the sole owner of partitions, filesystems, and mount points.
8. Keep firmware trust manual. The configuration may prepare and sign boot
   artifacts, but must never enroll Secure Boot keys by itself.
9. Keep `README.md` to procedures a reader cannot run from the configuration
   itself. Never restate option values, package lists, or shell aliases there.

## Safety

- Never install Nix or modify partitions on the macOS development host.
  Evaluation and system builds happen inside NixOS.
- Never commit passwords, hashes, LUKS passphrases, Secure Boot private keys,
  or TPM state.
- Do not update `flake.lock` implicitly. Update it deliberately from NixOS and
  review the diff.
