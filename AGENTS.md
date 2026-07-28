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
- `plasma.nix`: per-user Plasma configuration (plasma-manager).
- `hosts/<name>/`: hostname, install disk, and generated hardware scan.
- `modules/`: shared storage and boot concerns.

## Design rules

1. Nix files describe the computers. Keep them focused on the desired
   installed system: no CI checks, test derivations, formatter outputs,
   development shells, or test-only workarounds.
2. Track as much as the tooling allows. If a setting can be expressed as a
   NixOS, Home Manager, or plasma-manager option, declare it here rather than
   leaving it to a GUI, a mutable dotfile, or a vendor's own sync service.
   After changing anything in Plasma's System Settings, capture it with
   `nix run github:nix-community/plasma-manager#rc2nix` and commit the result.
   When an option genuinely does not exist, say so explicitly instead of
   quietly leaving the setting untracked.
3. Packages are installed system-wide in `configuration.nix`; their
   configuration is per-user in `home.nix` and `plasma.nix`. Where a Home
   Manager module would install a second copy of a system package, set
   `package = null` so it only writes configuration.
4. Optimize for a first-time reader. Prefer direct declarations and
   descriptive names over abstractions. Comment the reasons and the safety
   constraints, not the syntax.
5. Prefer ordinary NixOS options. Introduce a custom option only when it is
   the clean interface between genuinely separate modules, the way
   `nixos-config.storage.installDisk` sits between a host and the shared disk
   layout.
6. Keep Disko the sole owner of partitions, filesystems, and mount points.
7. Keep firmware trust manual. The configuration may prepare and sign boot
   artifacts, but must never enroll Secure Boot keys by itself.

## Safety

- Never install Nix or modify partitions on the macOS development host.
  Evaluation and system builds happen inside NixOS.
- Never commit passwords, hashes, LUKS passphrases, Secure Boot private keys,
  or TPM state.
- Do not update `flake.lock` implicitly. Update it deliberately from NixOS and
  review the diff.
