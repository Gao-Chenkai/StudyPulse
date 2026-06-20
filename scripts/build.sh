#!/usr/bin/env bash
# >>>HELP_START<<<
# =============================================================================
#  StudyPulse build helper
#  ----------------------------------------------------------------------------
#  Thin wrapper around `xcodebuild` for the StudyPulse iOS app.
#
#  Usage:
#      ./scripts/build.sh [command] [options]
#
#  Commands:
#      build       Build the app (default; Debug, iPhone 17 simulator)
#      release     Build with the Release configuration
#      clean       Remove the build folder and DerivedData
#      resolve     Resolve Swift Package Manager dependencies
#      test        Run unit / UI tests (none yet, placeholder)
#      archive     Archive the app for distribution
#      list        List available simulators and runtimes
#      help        Show this help
#
#  Options (apply to `build` / `release` / `archive` / `test`):
#      -d, --device <name>   Simulator / device name to build for
#      -c, --configuration <Debug|Release>
#      -s, --scheme <name>   Xcode scheme (default: StudyPulse)
#      -p, --project <path>  Xcode project (default: StudyPulse.xcodeproj)
#      -o, --output <dir>    Output directory for archive / build products
#      -q, --quiet           Reduce xcodebuild output (use `xcpretty` if found)
#      -h, --help            Show help
#
#  Examples:
#      ./scripts/build.sh
#      ./scripts/build.sh release
#      ./scripts/build.sh clean
#      ./scripts/build.sh build -d "iPhone 17 Pro"
#      ./scripts/build.sh archive -o build/StudyPulse.xcarchive
#      ./scripts/build.sh resolve
#      ./scripts/build.sh list
#
#  Requirements:
#      - Xcode 26.x (Command Line Tools are not enough for `xcodebuild`)
#      - macOS with `xcrun` available on PATH
# =============================================================================
# <<<HELP_END<<<

set -Eeuo pipefail

# -----------------------------------------------------------------------------
#  Defaults
# -----------------------------------------------------------------------------
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd)

PROJECT_PATH="${PROJECT_ROOT}/StudyPulse.xcodeproj"
SCHEME="StudyPulse"
CONFIGURATION="Debug"
SIMULATOR_NAME="iPhone 17"
OUTPUT_DIR="${PROJECT_ROOT}/build"
QUIET=0
COMMAND="build"

# -----------------------------------------------------------------------------
#  Logging helpers
# -----------------------------------------------------------------------------
color_reset="\033[0m"
color_bold="\033[1m"
color_blue="\033[0;34m"
color_green="\033[0;32m"
color_yellow="\033[0;33m"
color_red="\033[0;31m"

log_info()    { printf "%b[i]%b %s\n" "${color_blue}"   "${color_reset}" "$*"; }
log_success() { printf "%b[*]%b %s\n" "${color_green}"  "${color_reset}" "$*"; }
log_warn()    { printf "%b[!]%b %s\n" "${color_yellow}" "${color_reset}" "$*"; }
log_error()   { printf "%b[x]%b %s\n" "${color_red}"    "${color_reset}" "$*" >&2; }
log_title()   { printf "\n%b== %s ==%b\n" "${color_bold}${color_blue}" "$*" "${color_reset}"; }

die() {
    log_error "$*"
    exit 1
}

# -----------------------------------------------------------------------------
#  Help
# -----------------------------------------------------------------------------
print_help() {
    # Extract the help block delimited by the unique HELP_START / HELP_END
    # sentinel lines and strip the leading "# " prefix from each line.
    awk '
        /^# >>>HELP_START<<<$/{flag=1; next}
        /^# <<<HELP_END<<<$/{flag=0; next}
        flag{sub(/^# ?/, ""); print}
    ' "$0"
}

# -----------------------------------------------------------------------------
#  Argument parsing
# -----------------------------------------------------------------------------
parse_args() {
    if [[ $# -eq 0 ]]; then
        return 0
    fi

    # First positional argument is the command.
    case "${1:-}" in
        build|release|clean|resolve|test|archive|list|help|-h|--help)
            COMMAND="${1#--}"
            shift
            ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--device)
                SIMULATOR_NAME="$2"; shift 2 ;;
            -c|--configuration)
                CONFIGURATION="$2"; shift 2 ;;
            -s|--scheme)
                SCHEME="$2"; shift 2 ;;
            -p|--project)
                PROJECT_PATH="$2"; shift 2 ;;
            -o|--output)
                OUTPUT_DIR="$2"; shift 2 ;;
            -q|--quiet)
                QUIET=1; shift ;;
            -h|--help)
                print_help; exit 0 ;;
            *)
                die "Unknown option: $1. Run \`$SCRIPT_NAME help\` for usage."
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
#  Pre-flight checks
# -----------------------------------------------------------------------------
require_xcode() {
    if ! command -v xcodebuild > /dev/null 2>&1; then
        die "xcodebuild not found. Install Xcode 26.x and the Command Line Tools."
    fi
    if ! command -v xcrun > /dev/null 2>&1; then
        die "xcrun not found. Install the Command Line Tools (xcode-select --install)."
    fi
    if [[ ! -d "${PROJECT_PATH}" ]]; then
        die "Xcode project not found at: ${PROJECT_PATH}"
    fi
}

# -----------------------------------------------------------------------------
#  xcodebuild invocation
# -----------------------------------------------------------------------------
run_xcodebuild() {
    if [[ "${QUIET}" -eq 1 ]] && command -v xcpretty > /dev/null 2>&1; then
        xcodebuild "$@" | xcpretty
    elif [[ "${QUIET}" -eq 1 ]]; then
        xcodebuild "$@" -quiet
    else
        xcodebuild "$@"
    fi
}

# -----------------------------------------------------------------------------
#  Commands
# -----------------------------------------------------------------------------
cmd_build() {
    require_xcode
    log_title "Build  (${CONFIGURATION}, ${SIMULATOR_NAME})"

    mkdir -p "${OUTPUT_DIR}"

    run_xcodebuild \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
        -derivedDataPath "${OUTPUT_DIR}/DerivedData" \
        -clonedSourcePackagesDirPath "${OUTPUT_DIR}/SourcePackages" \
        CODE_SIGNING_ALLOWED=NO \
        build

    log_success "Build complete. Products in: ${OUTPUT_DIR}/DerivedData/Build/Products"
}

cmd_release() {
    CONFIGURATION="Release"
    cmd_build
}

cmd_clean() {
    require_xcode
    log_title "Clean"

    # Remove local build folder.
    if [[ -d "${OUTPUT_DIR}" ]]; then
        rm -rf "${OUTPUT_DIR}"
        log_info "Removed ${OUTPUT_DIR}"
    fi

    # Remove Xcode's per-user DerivedData for this scheme (best effort).
    local derived
    derived="${HOME}/Library/Developer/Xcode/DerivedData"
    if [[ -d "${derived}" ]]; then
        find "${derived}" -maxdepth 1 -type d -name "${SCHEME}-*" -exec rm -rf {} +
        log_info "Removed DerivedData entries for scheme ${SCHEME}"
    fi

    # Run xcodebuild clean on the project as well.
    run_xcodebuild \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
        clean || log_warn "xcodebuild clean returned non-zero (ignoring)."

    log_success "Clean complete."
}

cmd_resolve() {
    require_xcode
    log_title "Resolve SPM dependencies"
    run_xcodebuild \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME}" \
        -resolvePackageDependencies
    log_success "Package dependencies resolved."
}

cmd_test() {
    require_xcode
    log_title "Test  (${CONFIGURATION}, ${SIMULATOR_NAME})"
    log_warn "No test target is configured in this project yet."

    mkdir -p "${OUTPUT_DIR}"

    run_xcodebuild \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
        -derivedDataPath "${OUTPUT_DIR}/DerivedData" \
        CODE_SIGNING_ALLOWED=NO \
        test || log_warn "xcodebuild test returned non-zero (no test target?)."
}

cmd_archive() {
    require_xcode
    log_title "Archive  (${CONFIGURATION})"

    mkdir -p "${OUTPUT_DIR}"
    local archive_path="${OUTPUT_DIR}/${SCHEME}.xcarchive"
    if [[ -d "${archive_path}" ]]; then
        rm -rf "${archive_path}"
    fi

    run_xcodebuild \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "${archive_path}" \
        -derivedDataPath "${OUTPUT_DIR}/DerivedData" \
        -clonedSourcePackagesDirPath "${OUTPUT_DIR}/SourcePackages" \
        archive

    log_success "Archive created at: ${archive_path}"
}

cmd_list() {
    require_xcode
    log_title "Schemes"
    xcodebuild -list -project "${PROJECT_PATH}" || true

    log_title "Available iPhone simulators"
    xcrun simctl list devices available iPhone | sed 's/^/    /'
}

# -----------------------------------------------------------------------------
#  Entry point
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"

    case "${COMMAND}" in
        build)    cmd_build ;;
        release)  cmd_release ;;
        clean)    cmd_clean ;;
        resolve)  cmd_resolve ;;
        test)     cmd_test ;;
        archive)  cmd_archive ;;
        list)     cmd_list ;;
        help)     print_help ;;
        *)        die "Unknown command: ${COMMAND}. Run \`$SCRIPT_NAME help\` for usage." ;;
    esac
}

main "$@"
