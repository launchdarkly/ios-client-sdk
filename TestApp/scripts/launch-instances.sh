#!/usr/bin/env bash
# Builds the Mac test app and starts several instances of it, which share one event directory.
#
# Usage: launch-instances.sh [-c] [count] [-- app arguments...]
#   -c      Mac Catalyst rather than native macOS. The two have different bundle identifiers, so different directories.
#   count   How many instances to start; 2 by default.
#   Anything after -- is passed to every instance, such as -LDMobileKey mob-... or -LDEnvironment staging.
set -euo pipefail

catalyst=false
while getopts "c" option; do
    case "$option" in
        c) catalyst=true ;;
        *) sed -n '2,8p' "$0"; exit 64 ;;
    esac
done
shift $((OPTIND - 1))

count=2
if [[ $# -gt 0 && "$1" != "--" ]]; then
    count="$1"
    shift
fi
[[ "${1:-}" == "--" ]] && shift

test_app="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="$test_app/../build/testapp"

if $catalyst; then
    scheme=TestApp_iOS
    destination="platform=macOS,variant=Mac Catalyst"
    products=Debug-maccatalyst
else
    scheme=TestApp_macOS
    destination="platform=macOS"
    products=Debug
fi

xcodebuild build -quiet \
    -project "$test_app/TestApp.xcodeproj" \
    -scheme "$scheme" \
    -destination "$destination" \
    -derivedDataPath "$derived_data"

app="$derived_data/Build/Products/$products/TestApp.app"
for _ in $(seq "$count"); do
    if [[ $# -gt 0 ]]; then
        open -n "$app" --args "$@"
    else
        open -n "$app"
    fi
done
echo "Started $count instance(s) of $app"
