#!/usr/bin/env zsh
# Simulates the demo for asciinema recording
# Uses fn-stuff project with real session data

GRAY='\033[90m'
GREEN='\033[32m'
CYAN='\033[36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
YELLOW='\033[33m'
BG_BLUE='\033[44m'
WHITE='\033[97m'

simulate_type() {
    local text="$1"
    local delay="${2:-0.06}"
    for (( i=0; i<${#text}; i++ )); do
        printf '%s' "${text:$i:1}"
        sleep "$delay"
    done
}

prompt() {
    printf "${GREEN}~/repo/fn-stuff${RESET} ${CYAN}(master)${RESET} \$ "
}

# Draw the session list with one item highlighted
# Usage: draw_session_list <highlighted_index> <cursor_line>
# cursor_line = line to return cursor to after drawing
draw_session_list() {
    local highlight=$1
    local -a ids descs
    ids=(
        "0020aafa-52d6-4e44-8ee4-122f82c74a2c"
        "5c57f319-dfd6-4514-a3f6-9f3fd0849fe8"
        "a148abb9-899a-42a1-8d0b-963a2911e66c"
        "64a9ed65-e11d-49dc-979a-71b5b4b0d0b0"
        "b3700180-2582-4249-853c-2a5c6173d96a"
        "eef53a73-5f6d-4c82-8b0d-8573671890f5"
    )
    descs=(
        "no prompt (4d, master)"
        "we have a bug when user click on the contact (5d, master)"
        "hi (5d, fix/frontend-audit-fixes)"
        "fix frontend audit issues (5d, fix/frontend-audit-fixes)"
        "fix all issues, use playwright mcp (5d, master)"
        "continue fix all issues, auto run (5d, master)"
    )

    printf "  ${BOLD}claude session${RESET}\n"
    for (( i=1; i<=${#ids}; i++ )); do
        if (( i == highlight )); then
            printf "  ${BG_BLUE}${WHITE}${ids[$i]}  -- ${descs[$i]}${RESET}\n"
        else
            printf "  ${ids[$i]}  -- ${descs[$i]}\n"
        fi
    done
}

clear
printf "\n"
printf "  ${BOLD}zsh-claude-resume${RESET} — auto-resume Claude Code sessions\n"
printf "  ─────────────────────────────────────────────────────\n"
printf "\n"
sleep 1.5

# ── Scene 1: Ghost text autosuggestion ──
printf "  ${DIM}# 1. Type 'claude' — ghost text suggests your last session${RESET}\n\n"
sleep 1

prompt
sleep 0.3
simulate_type "c" && sleep 0.1
simulate_type "l" && sleep 0.1
simulate_type "a" && sleep 0.1
simulate_type "u" && sleep 0.1
simulate_type "d" && sleep 0.1
simulate_type "e"
sleep 0.3

# Ghost text appears
printf "${GRAY} --dangerously-skip-permissions --resume 0020aafa-52d6-4e44-8ee4-122f82c74a2c${RESET}"
sleep 2.5

# Accept with right arrow
printf "\r"
prompt
printf "claude --dangerously-skip-permissions --resume 0020aafa-52d6-4e44-8ee4-122f82c74a2c"
printf "  ${DIM}<- pressed -> to accept${RESET}"
sleep 2
printf "\n\n"

# ── Scene 2: Tab completion + arrow key navigation ──
printf "  ${DIM}# 2. Tab completion — browse sessions, use arrow keys to pick${RESET}\n\n"
sleep 1

# Save cursor position for the prompt line
prompt
simulate_type "claude --resume "
sleep 0.5
printf "${YELLOW}<TAB>${RESET}"
sleep 0.8
printf "\n\n"

# Draw initial list (no highlight)
draw_session_list 0
sleep 1.5

# Simulate pressing TAB again to enter selection mode — highlight first item
# Move cursor up 7 lines (header + 6 items) and redraw
printf "\033[7A\033[2K"  # move up, clear line
printf "\r"
# Redraw with highlight on item 1
draw_session_list 1
sleep 0.8

# Move highlight down to item 2
printf "\033[7A\033[2K"
printf "\r"
draw_session_list 2
printf "  ${DIM}  ↓ arrow key${RESET}"
sleep 0.8

# Move highlight down to item 3
printf "\033[8A\033[2K"
printf "\r"
draw_session_list 3
printf "  ${DIM}  ↓ arrow key${RESET}"
sleep 0.8

# Move highlight down to item 4
printf "\033[8A\033[2K"
printf "\r"
draw_session_list 4
printf "  ${DIM}  ↓ arrow key${RESET}"
sleep 1.5

# User presses Enter to select item 4
# Clear the completion list
printf "\033[8A"  # move up to prompt line
for (( i=0; i<9; i++ )); do
    printf "\033[2K\033[1B"  # clear line, move down
done
printf "\033[9A"  # move back up to prompt line
printf "\r"
prompt
printf "claude --resume 64a9ed65-e11d-49dc-979a-71b5b4b0d0b0"
printf "  ${DIM}<- selected with Enter${RESET}"
sleep 2.5
printf "\n\n"

# ── Scene 3: Narrow down by typing ──
printf "  ${DIM}# 3. Narrow down — type partial ID to filter, then pick${RESET}\n\n"
sleep 1

prompt
printf "claude --resume "
simulate_type "a"
sleep 0.4
printf "${YELLOW}<TAB>${RESET}"
sleep 0.8
printf "\n"

printf "\n"
printf "  ${BOLD}claude session${RESET}\n"
printf "  a148abb9-899a-42a1-8d0b-963a2911e66c  -- hi (5d, fix/frontend-audit-fixes)\n"
printf "  afd6c88c-5713-4875-b951-d401f6ba467a  -- upload debugging (5d, master)\n"
sleep 1.5

# Highlight first filtered item
printf "\033[3A\033[2K"
printf "\r"
printf "  ${BOLD}claude session${RESET}\n"
printf "  ${BG_BLUE}${WHITE}a148abb9-899a-42a1-8d0b-963a2911e66c  -- hi (5d, fix/frontend-audit-fixes)${RESET}\n"
printf "  afd6c88c-5713-4875-b951-d401f6ba467a  -- upload debugging (5d, master)\n"
sleep 1

# Select it
printf "\033[3A"
for (( i=0; i<4; i++ )); do
    printf "\033[2K\033[1B"
done
printf "\033[4A"
printf "\r"
prompt
printf "claude --resume a148abb9-899a-42a1-8d0b-963a2911e66c"
printf "  ${DIM}<- Enter${RESET}"
sleep 2.5
printf "\n"

# ── Summary ──
printf "\n"
printf "  ${BOLD}How it works:${RESET}\n"
printf "  ${DIM}  - Per-directory: each project suggests its own last session${RESET}\n"
printf "  ${DIM}  - Shows summary, time ago, and git branch${RESET}\n"
printf "  ${DIM}  - Arrow keys to navigate, Enter to select${RESET}\n"
printf "  ${DIM}  - Auto-detects flags from your history${RESET}\n"
printf "  ${DIM}  - Zero dependencies: pure ZSH + POSIX tools${RESET}\n"
printf "\n"
sleep 4
