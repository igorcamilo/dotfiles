# Nix module guidance

Files in this directory are installed-computer descriptions, never development
or CI harnesses. Follow the root `AGENTS.md` rules.

- Give each module one clear owner, such as storage, boot, or UTM integration.
- Split a file when two concerns can be named and understood independently.
- Keep related option declarations together so a reader can understand the
  complete behavior without chasing one-option fragments.
- Prefer ordinary NixOS options over custom options. Introduce a custom option
  only when it is the clean interface between genuinely separate modules.
- Do not add lint tools, test packages, check derivations, CI conditions, or
  test-only assertions here.
- Keep Disko as the sole owner of partitions, filesystems, and mount points.
- Keep firmware enrollment manual; configuration may prepare and sign boot
  artifacts but must not silently change firmware trust.
