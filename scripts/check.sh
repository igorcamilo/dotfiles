#!/usr/bin/env bash

# Repository-level checks. Run this inside `nix develop`.
#
# Every check runs even if an earlier check fails. This gives one complete
# report instead of requiring one fix-and-push cycle per hidden error.

set -uo pipefail

failures=0

run_check() {
  local name=$1
  local status
  shift

  printf '\n==> %s\n' "$name"
  if "$@"; then
    printf 'PASS: %s\n' "$name"
  else
    status=$?
    printf 'FAIL: %s (exit %d)\n' "$name" "$status" >&2
    failures=$((failures + 1))
  fi
}

check_nix_format() {
  find . -type f -name '*.nix' -print0 | xargs -0 nixfmt --check
}

check_dead_nix() {
  deadnix --fail .
}

check_nix_static_analysis() {
  statix check .
}

check_shell() {
  shellcheck -x install.sh tests/install-functions.sh scripts/check.sh
}

check_bash_syntax() {
  bash -n install.sh tests/install-functions.sh scripts/check.sh
}

check_installer() {
  bash tests/install-functions.sh
}

check_current_tree_for_secrets() {
  gitleaks detect --source . --no-git --redact --verbose
}

check_qml() {
  find dotfiles/quickshell -type f -name '*.qml' -print0 \
    | xargs -0 -n1 qmllint
}

run_check "Nix formatting" check_nix_format
run_check "Unused Nix code" check_dead_nix
run_check "Nix static analysis" check_nix_static_analysis
run_check "ShellCheck" check_shell
run_check "Bash syntax" check_bash_syntax
run_check "Installer tests" check_installer
run_check "Current-tree secret scan" check_current_tree_for_secrets
run_check "QML lint" check_qml

if ((failures > 0)); then
  printf '\n%d repository check(s) failed.\n' "$failures" >&2
  exit 1
fi

printf '\nAll repository checks passed.\n'
