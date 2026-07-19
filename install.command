#!/bin/zsh

set -u
set -o pipefail

REPOSITORY_ARCHIVE="https://github.com/miroshantoshan/materialSpeed/archive/refs/heads/main.tar.gz"
USER_APPS_DIR="$HOME/Applications"
TARGET_APP="$USER_APPS_DIR/materialSpeed.app"
WORK_DIR="$(mktemp -d -t materialspeed-installer)"
LOG_FILE="$WORK_DIR/installer.log"
ARCHIVE_PATH="$WORK_DIR/materialSpeed.tar.gz"
PROJECT_DIR="$WORK_DIR/materialSpeed-main"
SOURCE_APP="$PROJECT_DIR/dist/materialSpeed.app"

RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
PURPLE=$'\e[38;5;141m'
LIGHT_PURPLE=$'\e[38;5;183m'
CYAN=$'\e[38;5;81m'
GREEN=$'\e[38;5;114m'
RED=$'\e[38;5;203m'
GRAY=$'\e[38;5;245m'

cleanup() {
    if [[ -d "$WORK_DIR" && "${WORK_DIR:t}" == materialspeed-installer.* ]]; then
        rm -rf -- "$WORK_DIR"
    fi
}

trap cleanup EXIT

fail() {
    print ""
    print -- "${RED}${BOLD}  ✕ Installation failed${RESET}"
    print -- "${RED}  $1${RESET}"

    if [[ -s "$LOG_FILE" ]]; then
        print ""
        print -- "${GRAY}  Last messages:${RESET}"
        tail -n 12 "$LOG_FILE" | sed 's/^/    /'
    fi

    print ""
    print -n -- "${GRAY}Press Enter to close this window...${RESET}"
    read -r
    exit 1
}

header() {
    if [[ -t 1 ]]; then
        print -n -- $'\e]0;materialSpeed Installer\a'
        if [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]]; then
            print -n -- $'\e[8;30;54t'
            sleep 0.15
        fi
        clear
    fi
    print -- "${PURPLE}╭────────────────────────────────────────────╮${RESET}"
    print -- "${PURPLE}│${RESET}                                            ${PURPLE}│${RESET}"
    print -- "${PURPLE}│${RESET}       ${LIGHT_PURPLE}${BOLD}◉  materialSpeed Installer${RESET}           ${PURPLE}│${RESET}"
    print -- "${PURPLE}│${RESET}      ${GRAY}Fast. Private. Native for macOS.${RESET}      ${PURPLE}│${RESET}"
    print -- "${PURPLE}│${RESET}                                            ${PURPLE}│${RESET}"
    print -- "${PURPLE}╰────────────────────────────────────────────╯${RESET}"
    print ""
}

step() {
    print -- "${PURPLE}${BOLD}  $1${RESET} ${BOLD}$2${RESET}"
    print -- "${GRAY}      $3${RESET}"
}

run_with_spinner() {
    local label="$1"
    local minimum_seconds="$2"
    shift 2

    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local frame=1
    local started=$SECONDS

    : >"$LOG_FILE"
    "$@" >"$LOG_FILE" 2>&1 &
    local task_pid=$!

    while kill -0 "$task_pid" 2>/dev/null || (( SECONDS - started < minimum_seconds )); do
        print -n -- "\r${CYAN}      ${frames[$frame]} $label${RESET}   "
        frame=$((frame % ${#frames[@]} + 1))
        sleep 0.12
    done

    if wait "$task_pid"; then
        print -- "\r${GREEN}      ✓ $label${RESET}                 "
        return 0
    fi

    print -- "\r${RED}      ✕ $label${RESET}                    "
    return 1
}

animate_progress() {
    local start="$1"
    local finish="$2"
    local index empty bar part

    for ((index = start; index <= finish; index++)); do
        empty=$((20 - index))
        bar=""
        for ((part = 0; part < index; part++)); do bar+="█"; done
        for ((part = 0; part < empty; part++)); do bar+="░"; done
        print -n -- "\r${LIGHT_PURPLE}      [$bar]${RESET}  $((index * 5))%"
        sleep 0.1
    done
    print ""
}

ensure_swift() {
    if command -v swift >/dev/null 2>&1 && swift --version >/dev/null 2>&1; then
        return 0
    fi

    step "SETUP" "Developer tools" "Installing Apple's free Swift compiler"
    xcode-select --install >/dev/null 2>&1 || true

    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local frame=1
    local started=$SECONDS

    while ! swift --version >/dev/null 2>&1; do
        (( SECONDS - started < 1200 )) || fail "Developer Tools installation timed out."
        print -n -- "\r${CYAN}      ${frames[$frame]} Waiting for Developer Tools...${RESET}   "
        frame=$((frame % ${#frames[@]} + 1))
        sleep 2
    done

    print -- "\r${GREEN}      ✓ Developer Tools are ready${RESET}             "
    print ""
}

close_terminal_window() {
    if [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]]; then
        nohup /usr/bin/osascript \
            -e 'delay 0.5' \
            -e 'tell application "Terminal" to close front window' \
            >/dev/null 2>&1 &
    fi
}

header

command -v curl >/dev/null 2>&1 || fail "curl is required but was not found."
command -v tar >/dev/null 2>&1 || fail "tar is required but was not found."
ensure_swift

step "1/4" "Download source" "Fetching the latest main branch from GitHub"
if ! run_with_spinner "Downloading materialSpeed..." 3 \
    curl --fail --location --silent --show-error --retry 3 \
    "$REPOSITORY_ARCHIVE" --output "$ARCHIVE_PATH"; then
    fail "Could not download materialSpeed. Check your internet connection."
fi

tar -xzf "$ARCHIVE_PATH" -C "$WORK_DIR" >"$LOG_FILE" 2>&1 \
    || fail "The downloaded source archive could not be unpacked."
[[ -f "$PROJECT_DIR/Package.swift" ]] || fail "The downloaded project is incomplete."
[[ -x "$PROJECT_DIR/package_app.sh" ]] || chmod +x "$PROJECT_DIR/package_app.sh"
print ""

step "2/4" "Build application" "Creating an optimized app from local source code"
run_with_spinner "Compiling Swift sources..." 5 "$PROJECT_DIR/package_app.sh" \
    || fail "Swift could not build materialSpeed."
[[ -d "$SOURCE_APP" ]] || fail "The application bundle was not created."
print ""

step "3/4" "Install application" "Copying materialSpeed to your Applications folder"
animate_progress 0 12
mkdir -p "$USER_APPS_DIR" || fail "Could not create $USER_APPS_DIR."

if [[ -e "$TARGET_APP" ]]; then
    [[ "$TARGET_APP" == "$HOME/Applications/materialSpeed.app" ]] || fail "Unsafe installation path."
    rm -rf -- "$TARGET_APP" || fail "Could not replace the previous installation."
fi

ditto "$SOURCE_APP" "$TARGET_APP" || fail "Could not copy the application."
animate_progress 13 20
print -- "${GREEN}      ✓ Installed in ~/Applications${RESET}"
print ""

step "4/4" "Launch" "Starting materialSpeed"
sleep 1
open "$TARGET_APP" || fail "The application was installed but could not be opened."
print -- "${GREEN}      ✓ materialSpeed is ready${RESET}"
print ""
print -- "${PURPLE}╭────────────────────────────────────────────╮${RESET}"
print -- "${PURPLE}│${RESET}    ${GREEN}${BOLD}Installation completed successfully${RESET}     ${PURPLE}│${RESET}"
print -- "${PURPLE}╰────────────────────────────────────────────╯${RESET}"
print ""
print -- "${DIM}  Temporary source files will now be removed.${RESET}"
sleep 1

cleanup
trap - EXIT
close_terminal_window
exit 0
