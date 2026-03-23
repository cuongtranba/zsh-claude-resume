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
    printf "${GREEN}~/Desktop/repo/fn-stuff${RESET} ${CYAN}(master)${RESET} \$ "
}

clear
printf "\n"
printf "  ${BOLD}zsh-claude-resume${RESET} — auto-resume Claude Code sessions\n"
printf "  ─────────────────────────────────────────────────────\n"
printf "\n"
sleep 1.5

# ── Scene 1: Ghost text autosuggestion ──
printf "  ${DIM}# 1. Ghost text: type 'claude' and the last session appears${RESET}\n\n"
sleep 1

prompt
sleep 0.3

# Type "claude" letter by letter
simulate_type "c" && sleep 0.1
simulate_type "l" && sleep 0.1
simulate_type "a" && sleep 0.1
simulate_type "u" && sleep 0.1
simulate_type "d" && sleep 0.1
simulate_type "e"
sleep 0.3

# Show ghost text appearing
printf "${GRAY} --dangerously-skip-permissions --resume 0020aafa-52d6-4e44-8ee4-122f82c74a2c${RESET}"
sleep 2.5

# Simulate pressing right arrow — ghost text becomes real
printf "\r"
prompt
printf "claude --dangerously-skip-permissions --resume 0020aafa-52d6-4e44-8ee4-122f82c74a2c"
sleep 0.5
printf "  ${DIM}<- pressed ->  to accept${RESET}"
sleep 2
printf "\n\n"

# ── Scene 2: Tab completion ──
printf "  ${DIM}# 2. Tab completion: browse all sessions with details${RESET}\n\n"
sleep 1

prompt
simulate_type "claude --resume "
sleep 0.5
printf "${YELLOW}<TAB>${RESET}"
sleep 1
printf "\n"

# Show completion list
printf "\n"
printf "  ${BOLD}claude session${RESET}\n"
printf "  0020aafa-52d6-4e44-8ee4-122f82c74a2c  -- session (now, master)\n"
printf "  afd6c88c-5713-4875-b951-d401f6ba467a  -- session (16h, master)\n"
printf "  10cf54ed-ffe7-4212-9a78-5f87b0c21f95  -- session (1d, master)\n"
printf "  5c57f319-dfd6-4514-a3f6-9f3fd0849fe8  -- session (1d, master)\n"
printf "  a148abb9-899a-42a1-8d0b-963a2911e66c  -- session (2d, fix/frontend-audit-fixes)\n"
sleep 2.5
printf "\n"

# ── Scene 3: Narrow down ──
printf "  ${DIM}# 3. Narrow down: type partial ID to filter${RESET}\n\n"
sleep 1

prompt
printf "claude --resume "
simulate_type "a"
sleep 0.4
printf "${YELLOW}<TAB>${RESET}"
sleep 0.8
printf "\n"

# Show filtered list (only sessions starting with 'a')
printf "\n"
printf "  ${BOLD}claude session${RESET}\n"
printf "  afd6c88c-5713-4875-b951-d401f6ba467a  -- session (16h, master)\n"
printf "  a148abb9-899a-42a1-8d0b-963a2911e66c  -- session (2d, fix/frontend-audit-fixes)\n"
sleep 2

printf "\n"
prompt
printf "claude --resume a"
simulate_type "148"
sleep 0.3
printf "${YELLOW}<TAB>${RESET}"
sleep 0.5

# Auto-complete the full ID
printf "\r"
prompt
printf "claude --resume a148abb9-899a-42a1-8d0b-963a2911e66c"
printf "  ${DIM}<- auto-completed${RESET}"
sleep 2.5
printf "\n"

# ── Summary ──
printf "\n"
printf "  ${BOLD}How it works:${RESET}\n"
printf "  ${DIM}  - Per-directory: each project suggests its own last session${RESET}\n"
printf "  ${DIM}  - Auto-detects flags from your history (--dangerously-skip-permissions)${RESET}\n"
printf "  ${DIM}  - Zero dependencies: pure ZSH + POSIX tools${RESET}\n"
printf "\n"
sleep 4
