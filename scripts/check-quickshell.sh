#!/usr/bin/env bash

# Load every complete Quickshell configuration with the real binary.
# A successful configuration stays running, so timeout exit codes are expected.

set -euo pipefail

source_root=${1:?Usage: check-quickshell.sh CONFIG_ROOT}
state_root=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-check.XXXXXX")
config_root="$state_root/configs"

cleanup() {
  rm -rf -- "$state_root"
}
trap cleanup EXIT

cp -R "$source_root" "$config_root"
chmod -R u+w "$config_root"

if [[ -z ${QML_IMPORT_PATH:-} ]]; then
  for binary in qmllint quickshell; do
    binary_path=$(readlink -f "$(command -v "$binary")")
    package_root=$(dirname "$(dirname "$binary_path")")
    qml_path="$package_root/lib/qt-6/qml"
    QML_IMPORT_PATH="${QML_IMPORT_PATH:+$QML_IMPORT_PATH:}$qml_path"
  done
  export QML_IMPORT_PATH
fi

export NO_COLOR=1
export QSG_RHI_BACKEND=software
export QS_NO_RELOAD_POPUP=1
export QT_QPA_PLATFORM=offscreen
export XDG_CACHE_HOME="$state_root/cache"
export XDG_CONFIG_HOME="$state_root/config"
export XDG_DATA_HOME="$state_root/data"
export XDG_RUNTIME_DIR="$state_root/runtime"
export XDG_STATE_HOME="$state_root/state"

mkdir -p "$state_root"/{cache,config,data,runtime,state}
chmod 700 "$XDG_RUNTIME_DIR"

load_config() {
  local name=$1
  local log="$state_root/$name.log"
  local status

  if timeout --kill-after=1s 4s \
    quickshell --no-color --path "$config_root/$name" >"$log" 2>&1
  then
    status=0
  else
    status=$?
  fi

  if [[ $status -ne 0 && $status -ne 124 && $status -ne 137 ]]; then
    printf 'Quickshell exited unexpectedly while loading %s:\n' "$name" >&2
    cat "$log" >&2
    return "$status"
  fi

  if ! grep -Fq "Configuration Loaded" "$log"; then
    printf 'Quickshell did not confirm that it loaded %s:\n' "$name" >&2
    cat "$log" >&2
    return 1
  fi
}

load_config bar
load_config greeter
load_config lockscreen
