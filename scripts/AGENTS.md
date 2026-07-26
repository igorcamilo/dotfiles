# Validation script guidance

Development and CI behavior belongs here instead of in Nix modules or flake
outputs.

- Keep scripts readable from top to bottom and give every script one entry
  purpose.
- Obtain temporary tools from the repository's locked `nixpkgs` input with
  `nix shell --inputs-from`; do not reintroduce a development shell or check
  output in `flake.nix`.
- Both native architectures must run the same `check-system.sh` code path.
- Architecture-neutral formatting, static analysis, shell tests, QML linting,
  and secret scans run separately and only once.
- A test must not require changes to the installed-computer description merely
  to make the test environment work. Fix or remove such a test instead.
- Never write generated test state into the checkout. Use a temporary directory
  and clean it on exit.
- Use absolute interpreters supplied by Nix when a test executes inside a Nix
  build sandbox.
