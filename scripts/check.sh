#!/usr/bin/env bash

# Repository-level checks. scripts/check-repository.sh supplies the tools.
#
# Every check runs even if an earlier check fails. This gives one complete
# report instead of requiring one fix-and-push cycle per hidden error.

set -uo pipefail

failures=0

# hosts/*/hardware-configuration.nix is nixos-generate-config's own output
# (its header says not to hand-edit it), so its style is the generator's, not
# this repository's: the checks below that hit it skip it. lefthook.yml reads
# this same file so the exemption can't drift out of sync between CI and the
# local pre-commit hook again.
generated_nix_glob=$(cat scripts/generated-nix-files.glob)

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
  local file
  local formatted
  local status=0
  local temp_dir

  temp_dir=$(mktemp -d)
  formatted="$temp_dir/formatted.nix"

  # Format a copy so CI can print the exact patch without changing the tree.
  while IFS= read -r -d '' file; do
    cp "$file" "$formatted"

    if ! nixfmt "$formatted"; then
      printf 'nixfmt could not parse %s\n' "$file" >&2
      status=1
      continue
    fi

    if ! diff -u \
      --label "$file" \
      --label "$file (formatted)" \
      "$file" "$formatted"
    then
      status=1
    fi
  done < <(find . -type f -name '*.nix' -not -path "./$generated_nix_glob" -print0)

  rm -f "$formatted"
  rmdir "$temp_dir"
  return "$status"
}

check_dead_nix() {
  # shellcheck disable=SC2086 # deadnix --exclude wants expanded paths, not a glob string
  deadnix --fail --exclude $generated_nix_glob -- .
}

check_nix_static_analysis() {
  statix check -i "$generated_nix_glob" .
}

check_shell() {
  shellcheck -x \
    install.sh \
    tests/install-functions.sh \
    scripts/check.sh \
    scripts/check-repository.sh \
    scripts/check-system.sh
}

check_bash_syntax() {
  bash -n \
    install.sh \
    tests/install-functions.sh \
    scripts/check.sh \
    scripts/check-repository.sh \
    scripts/check-system.sh
}

check_installer() {
  bash tests/install-functions.sh
}

check_current_tree_for_secrets() {
  gitleaks detect --source . --no-git --redact --verbose
}

check_qml() {
  local file
  local import_path
  local log
  local package_root
  local -a import_arguments=()
  local -a import_paths=()
  local -a qml_files=()

  if [[ -n ${QML_IMPORT_PATH:-} ]]; then
    local IFS=:
    read -r -a import_paths <<< "$QML_IMPORT_PATH"
  else
    for file in qmllint quickshell; do
      if ! package_root=$(readlink -f "$(command -v "$file")"); then
        printf 'Could not locate %s in PATH.\n' "$file" >&2
        return 1
      fi
      package_root=$(dirname "$(dirname "$package_root")")
      import_paths+=("$package_root/lib/qt-6/qml")
    done
  fi

  for import_path in "${import_paths[@]}"; do
    if [[ -n $import_path ]]; then
      import_arguments+=(-I "$import_path")
    fi
  done

  log=$(mktemp)

  while IFS= read -r -d '' file; do
    qml_files+=("$file")
  done < <(
    # dotfiles/quickshell/greeter/ is shelved, undeployed work kept for a
    # later Hyprland+Quickshell greeter; it's not wired into home.nix and its
    # imports are stale until it's reinstated, so it's excluded here rather
    # than kept passing by coincidence.
    find dotfiles/quickshell -type f -name '*.qml' -not -path 'dotfiles/quickshell/greeter/*' -print0
  )

  # Known Quickshell tooling warnings stay hidden; real failures print the log.
  if ! qmllint "${import_arguments[@]}" --import=error \
    "${qml_files[@]}" >"$log" 2>&1
  then
    printf 'QML lint failed:\n' >&2
    cat "$log" >&2
    rm -f "$log"
    return 1
  fi

  rm -f "$log"
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
