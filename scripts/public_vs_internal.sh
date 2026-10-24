#!/usr/bin/env bash
# Builds CoreKit twice, Release + stripped, with identical code:
#   1. every generated type/member marked `public`
#   2. the same code with `internal` access
# and prints how big the binary is and what each Mach-O segment holds.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=build/public-vs-internal
mkdir -p "$OUT"

build_corekit() {
  local access=$1
  python3 -I scripts/generate_corekit.py --access "$access" >/dev/null
  tuist generate --no-open >/dev/null
  xcodebuild build \
    -workspace MyApp.xcworkspace \
    -scheme CoreKit \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$OUT/DerivedData-$access" \
    CODE_SIGNING_ALLOWED=NO \
    DEPLOYMENT_POSTPROCESSING=YES \
    -quiet
  cp "$OUT/DerivedData-$access/Build/Products/Release-iphoneos/CoreKit.framework/CoreKit" "$OUT/CoreKit-$access"
}

segment() { size -m "$1" | awk -v s="$2" '$1=="Segment" && $2==s":" {print int(($3+1023)/1024)}'; }
section() { size -m "$1" | awk -v s="$2" '$1=="Section" && $2==s":" {sum+=$3} END {print int((sum+1023)/1024)}'; }

trap 'python3 -I scripts/generate_corekit.py --access public >/dev/null; tuist generate --no-open >/dev/null' EXIT

build_corekit public
build_corekit internal

printf "\n%-26s %10s %10s\n" "CoreKit (Release, stripped)" "public" "internal"
for a in public internal; do eval "f_$a=$OUT/CoreKit-$a"; done
printf "%-26s %8s KB %7s KB\n" "binary on disk" \
  $(( ($(stat -f%z "$f_public") + 1023) / 1024 )) $(( ($(stat -f%z "$f_internal") + 1023) / 1024 ))
printf "%-26s %8s KB %7s KB\n" "__TEXT,__text (code)" "$(section "$f_public" __text)" "$(section "$f_internal" __text)"
printf "%-26s %8s KB %7s KB\n" "__const (all segments)" "$(section "$f_public" __const)" "$(section "$f_internal" __const)"
printf "%-26s %8s KB %7s KB\n" "__LINKEDIT segment" "$(segment "$f_public" __LINKEDIT)" "$(segment "$f_internal" __LINKEDIT)"
printf "%-26s %10s %10s\n" "exported symbols" "$(nm -gU "$f_public" | wc -l | tr -d ' ')" "$(nm -gU "$f_internal" | wc -l | tr -d ' ')"
