# Repository guide for coding agents

Read `README.md` first, then `docs/architecture.md`. Together they explain the
machines, terminology, file layout, installation flow, and security model.

This root file is the one canonical set of agent instructions. It deliberately
uses the tool-neutral `AGENTS.md` convention and does not depend on
vendor-specific per-agent files or nested-file discovery.

## Non-negotiable design rules

1. Nix files describe the computers.
   - Keep them focused on the desired installed system.
   - Do not add CI checks, test derivations, formatter outputs, development
     shells, lint package lists, or test-only workarounds to Nix files.
   - An operational flake app is acceptable only when the repository itself
     uses it to install or operate a machine.
2. Optimize for a first-time reader.
   - Prefer direct declarations and descriptive names over abstractions.
   - Split a Nix file when it contains independently understandable concerns
     with clear names.
   - Do not create tiny modules or generic frameworks that add navigation
     without clarifying ownership.
   - Add comments for reasons and safety constraints, not for obvious syntax.
3. This is a two-host personal configuration, not a fleet framework.
   - Shared behavior belongs in the root configuration or `modules/`.
   - Hardware, hostname, disk identity, and guest-only behavior belong under
     `hosts/<name>/`.
   - Do not add deployment frameworks, automatic discovery, or fleet
     abstractions without an explicit request.
4. Development and CI logic belongs outside Nix.
   - Put reusable validation in `scripts/` and installer tests in `tests/`.
   - Keep x86_64 and AArch64 system validation identical.
   - Run architecture-neutral checks once in a separate CI job.

## Nix module boundaries

- Give each module one clear owner, such as storage, boot, or UTM integration.
- Split a file when two concerns can be named and understood independently.
- Keep related option declarations together so a reader can understand the
  complete behavior without chasing one-option fragments.
- Prefer ordinary NixOS options over custom options. Introduce a custom option
  only when it is the clean interface between genuinely separate modules.
- Keep Disko as the sole owner of partitions, filesystems, and mount points.
- Keep firmware enrollment manual. Configuration may prepare and sign boot
  artifacts but must not silently change firmware trust.

## Validation architecture

- Keep scripts readable from top to bottom and give every script one purpose.
- Obtain temporary tools from the locked `nixpkgs` input with
  `nix shell --inputs-from`; do not add development or check outputs to the
  flake.
- Both native architectures run the same `check-system.sh` code path through
  one CI matrix. Only the host, Nix system, and native runner differ.
- Formatting, static analysis, shell tests, QML linting, and current-tree
  secret scanning run once in a separate repository-quality job.
- Full-history secret scanning remains separate from native system validation.
- Every CI Nix command uses the committed lock without updating it.
- Do not add emulation or cross-compilation for these two machines.
- A test must not require a workaround in the installed-computer description.
  Fix or remove such a test instead.
- Never write generated test state into the checkout.

## Repository map

- `flake.nix`: locked inputs, shared module composition, two NixOS outputs, and
  the Disko app used by `install.sh`.
- `configuration.nix`: shared machine-wide operating-system configuration.
- `home.nix`: shared user-session configuration.
- `hosts/igor-desktop/`: physical x86_64 host facts.
- `hosts/igor-vm/`: UTM AArch64 guest facts.
- `modules/`: shared storage, boot, and virtualization concerns.
- `dotfiles/`: Hyprland and Quickshell runtime configuration.
- `install.sh`: destructive installation workflow.
- `scripts/`: non-destructive development and CI validation.
- `tests/`: installer and QML validation fixtures.
- `docs/`: installation, architecture, recovery, and Secure Boot procedures.

## Safety and validation

- Never install Nix or modify partitions on the macOS development host.
- Never commit passwords, hashes, LUKS passphrases, Secure Boot private keys,
  or TPM state.
- Preserve the clean-checkout and exact-device confirmation boundaries in
  `install.sh`.
- Do not update `flake.lock` implicitly. Generate and validate dependency
  changes in NixOS.
- Use the native NixOS VM or CI for Nix evaluation and system builds.
- Before handing off a change, run every relevant macOS-safe syntax and unit
  check and state which native Nix checks remain for CI.
