#!/usr/bin/env bash
# Archives MyApp (Release, device) in each merge mode and prints what ended up in the .app.
#
#   ./scripts/measure.sh                  # none + automatic + manual
#   ./scripts/measure.sh none automatic   # pick modes
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ $# -gt 0 ]]; then MODES=("$@"); else MODES=(none automatic manual); fi
OUT=build/measure
mkdir -p "$OUT"

kb() { echo $(( ($(stat -f%z "$1") + 1023) / 1024 )); }

dir_kb() { du -sk "$1" | cut -f1; }

archive() {
  local mode=$1
  echo "==> Archiving with MERGE_MODE=$mode"
  TUIST_MERGE_MODE=$mode tuist generate --no-open >/dev/null
  xcodebuild archive \
    -workspace MyApp.xcworkspace \
    -scheme MyApp \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$OUT/$mode.xcarchive" \
    -derivedDataPath "$OUT/DerivedData-$mode" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet
}

report() {
  local mode=$1
  local app="$OUT/$mode.xcarchive/Products/Applications/MyApp.app"
  echo
  echo "---------- $mode ----------"
  printf "%-28s %8s\n" ".app total (du)" "$(dir_kb "$app") KB"
  printf "%-28s %8s\n" "MyApp executable" "$(kb "$app/MyApp") KB"
  for fw in CoreKit SupportFeature ProfileFeature; do
    local bin="$app/Frameworks/$fw.framework/$fw"
    if [[ -f "$bin" ]]; then
      printf "%-28s %8s\n" "$fw executable" "$(kb "$bin") KB"
    else
      printf "%-28s %8s\n" "$fw executable" "(none)"
    fi
  done
  echo "Frameworks/ folder: $(ls "$app/Frameworks" 2>/dev/null | tr '\n' ' ')"
}

for mode in "${MODES[@]}"; do archive "$mode"; done
for mode in "${MODES[@]}"; do report "$mode"; done

# Put the project back to the default mode.
tuist generate --no-open >/dev/null
