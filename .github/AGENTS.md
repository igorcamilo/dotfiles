# GitHub Actions guidance

Follow the root `AGENTS.md` rules. CI must remain visibly separate from the
computer descriptions.

- The x86_64 and AArch64 validations are entries in one matrix with one shared
  step list. Only host, Nix system, and native runner may differ.
- Do not put architecture-neutral checks into one matrix entry conditionally.
  Run them once in a separate repository-quality job.
- Keep full-history secret scanning separate from native system validation.
- Every Nix command uses the committed lock without updating it.
- Native system jobs build their matching host; do not add emulation or
  cross-compilation for these two machines.
- CI workarounds belong in workflow or shell tooling, never in `.nix` files.
