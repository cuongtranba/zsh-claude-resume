#!/usr/bin/env zsh
# zsh-claude-resume — Auto-suggest and tab-complete Claude Code --resume sessions
#
# Features:
#   1. Ghost text autosuggestion when typing "claude" (zsh-autosuggestions custom strategy)
#   2. Tab completion for "claude --resume <TAB>" with session details
#
# Dependencies: NONE (pure zsh + standard POSIX tools)
# Requires: zsh-autosuggestions (for ghost text feature)
# Install:  Add to oh-my-zsh custom plugins and load AFTER zsh-autosuggestions
#
#   plugins=(git zsh-autosuggestions zsh-claude-resume)

# ─── Configuration ──────────────────────────────────────────────────────────────

(( ! ${+ZSH_CLAUDE_RESUME_MAX_SESSIONS} )) && typeset -g ZSH_CLAUDE_RESUME_MAX_SESSIONS=10
(( ! ${+ZSH_CLAUDE_RESUME_CACHE_TTL} ))    && typeset -g ZSH_CLAUDE_RESUME_CACHE_TTL=5
(( ! ${+ZSH_CLAUDE_RESUME_AUTO_FLAGS} ))    && typeset -g ZSH_CLAUDE_RESUME_AUTO_FLAGS=true

# ─── Internal State ─────────────────────────────────────────────────────────────

zmodload zsh/datetime 2>/dev/null

typeset -gA _zcr_session_cache   # "cwd" -> "epoch session_id"
typeset -g  _zcr_common_flags="" # detected flags (e.g. " --dangerously-skip-permissions")

# ─── Helpers ────────────────────────────────────────────────────────────────────

# Get most recent session ID for cwd (cached)
_zcr_latest_session() {
    local now=${EPOCHSECONDS:-$(command date +%s)}
    local cache_val="${_zcr_session_cache[$PWD]}"

    if [[ -n "$cache_val" ]]; then
        local cache_time="${cache_val%% *}"
        local cache_id="${cache_val#* }"
        if (( now - cache_time < ZSH_CLAUDE_RESUME_CACHE_TTL )); then
            print -r -- "$cache_id"
            return
        fi
    fi

    local project_dir="${HOME}/.claude/projects/${PWD//[\/.]/-}"
    local session_id

    # Primary: most recent entry in project dir (handles both .jsonl files and directories)
    if [[ -d "$project_dir" ]]; then
        local latest
        latest=$(command ls -t "$project_dir" 2>/dev/null | command grep -vE "^(sessions-index\.json|memory)$" | command head -1)
        [[ -n "$latest" ]] && session_id="${latest%.jsonl}"
    fi

    # Fallback: scan PID session files matching current directory
    if [[ -z "$session_id" ]]; then
        local pid_dir="${HOME}/.claude/sessions"
        if [[ -d "$pid_dir" ]]; then
            session_id=$(command grep -l "\"cwd\":\"${PWD}\"" "$pid_dir"/*.json 2>/dev/null | \
                while read -r f; do
                    local started sid
                    started=$(command grep -o '"startedAt":[0-9]*' "$f" | command head -1)
                    started="${started#*:}"
                    sid=$(command grep -o '"sessionId":"[^"]*"' "$f" | command head -1)
                    sid="${sid#*\"sessionId\":\"}"
                    sid="${sid%\"}"
                    [[ -n "$started" && -n "$sid" ]] && print -r -- "${started} ${sid}"
                done | command sort -rn | command head -1 | command cut -d' ' -f2)
        fi
    fi

    [[ -z "$session_id" ]] && return 1

    _zcr_session_cache[$PWD]="$now $session_id"
    print -r -- "$session_id"
}

# Detect common flags from zsh history (run once at load)
_zcr_detect_flags() {
    [[ "$ZSH_CLAUDE_RESUME_AUTO_FLAGS" != true ]] && return

    local most_common hist_source

    # Try fc first (interactive sessions), fall back to HISTFILE
    hist_source=$(fc -l -n -500 2>/dev/null)
    if [[ -z "$hist_source" ]]; then
        local hfile="${HISTFILE:-$HOME/.zsh_history}"
        [[ -f "$hfile" ]] && hist_source=$(command tail -500 "$hfile" | command sed 's/^: [0-9]*:[0-9]*;//')
    fi
    [[ -z "$hist_source" ]] && return

    most_common=$(print -r -- "$hist_source" | \
        command grep -E "^claude " | \
        command grep -vE "(--resume|--continue| -r | -c |mcp |doctor|setup|update|config )" | \
        command sed 's/^ *//;s/ *$//' | \
        LC_ALL=C command sort | LC_ALL=C command uniq -c | LC_ALL=C command sort -rn | \
        command head -1 | command sed 's/^ *[0-9]* *//')

    if [[ -n "$most_common" && "$most_common" != "claude" ]]; then
        _zcr_common_flags="${most_common#claude}"
        _zcr_common_flags=" ${_zcr_common_flags## }"
        _zcr_common_flags="${_zcr_common_flags%% }"
    fi
}

# Format seconds into human-readable time ago
_zcr_format_ago() {
    local diff=$1
    if   (( diff < 60 ));     then print -r -- "now"
    elif (( diff < 3600 ));   then print -r -- "$(( diff / 60 ))m"
    elif (( diff < 86400 ));  then print -r -- "$(( diff / 3600 ))h"
    elif (( diff < 604800 )); then print -r -- "$(( diff / 86400 ))d"
    else                           print -r -- "$(( diff / 604800 ))w"
    fi
}

# ─── Autosuggestion Strategy ───────────────────────────────────────────────────
# Called by zsh-autosuggestions on every keystroke. Must set $suggestion.

_zsh_autosuggest_strategy_claude_resume() {
    typeset -g suggestion=""

    # Only activate when user has typed at least "claude"
    [[ "$1" != claude* ]] && return

    local session_id
    session_id=$(_zcr_latest_session) || return

    # Build candidates: with flags first, bare second
    local with_flags="claude${_zcr_common_flags} --resume ${session_id}"
    local bare="claude --resume ${session_id}"

    if [[ "$with_flags" == "$1"* ]]; then
        suggestion="$with_flags"
    elif [[ "$bare" == "$1"* ]]; then
        suggestion="$bare"
    fi
}

# ─── Tab Completion ─────────────────────────────────────────────────────────────

_zcr_complete_sessions() {
    local index_file="${HOME}/.claude/projects/${PWD//[\/.]/-}/sessions-index.json"
    local project_dir="${HOME}/.claude/projects/${PWD//[\/.]/-}"
    local -a sessions
    local now=${EPOCHSECONDS:-$(command date +%s)}

    if [[ -f "$index_file" ]]; then
        # Parse sessions-index.json with awk (no jq needed)
        local id summary modified branch then_epoch time_ago
        while IFS=$'\t' read -r modified id summary branch; do
            [[ -z "$id" ]] && continue

            # Calculate time ago from ISO date
            then_epoch=$(command date -j -f "%Y-%m-%dT%H:%M:%S" "${modified%%.*}" +%s 2>/dev/null || \
                command date -d "${modified}" +%s 2>/dev/null || print 0)
            if (( then_epoch > 0 )); then
                time_ago=$(_zcr_format_ago $(( now - then_epoch )))
            else
                time_ago="?"
            fi

            summary="${summary:0:50}"
            sessions+=("${id}:${summary} (${time_ago}, ${branch})")
        done < <(command awk -F'"' '
            /"sessionId"/  { sid = $4 }
            /"summary"/    { sum = $4 }
            /"modified"/   { mod = $4 }
            /"gitBranch"/  { br  = $4 }
            /\}/ {
                if (sid != "" && mod != "") {
                    print mod "\t" sid "\t" sum "\t" br
                    sid = ""; sum = ""; mod = ""; br = ""
                }
            }
        ' "$index_file" | command sort -r | command head -"$ZSH_CLAUDE_RESUME_MAX_SESSIONS")
    else
        # Fallback: list JSONL files by modification time, extract summary from content
        local f id file_epoch time_ago prompt branch desc
        for f in $(command ls -t "$project_dir"/*.jsonl 2>/dev/null | command head -"$ZSH_CLAUDE_RESUME_MAX_SESSIONS"); do
            id="${f:t:r}"
            file_epoch=$(command stat -f %m "$f" 2>/dev/null || command stat -c %Y "$f" 2>/dev/null || print 0)
            time_ago="?"
            (( file_epoch > 0 )) && time_ago=$(_zcr_format_ago $(( now - file_epoch )))

            # Extract first real user prompt and git branch from JSONL
            prompt=$(command grep '"promptId"' "$f" 2>/dev/null | command grep '"type":"user"' | \
                command grep -v 'Caveat:' | command grep -v 'local-command' | command head -1 | \
                command sed 's/.*"content"://;s/}.*//;s/^\[{[^}]*"text":"//;s/^"//;s/".*//;s/<[^>]*>//g;s/^[0-9T:.Z -]*//' | cut -c1-50)
            branch=$(command grep -o '"gitBranch":"[^"]*"' "$f" 2>/dev/null | command head -1 | command sed 's/"gitBranch":"//;s/"//')

            desc="${prompt:-no prompt}"
            [[ -n "$branch" ]] && desc="${desc} (${time_ago}, ${branch})" || desc="${desc} (${time_ago})"
            sessions+=("${id}:${desc}")
        done
    fi

    (( ${#sessions} == 0 )) && return 1
    _describe 'claude session' sessions
}

_zcr_complete_claude() {
    _arguments \
        '(-r --resume)'{-r,--resume}'[Resume a conversation by session ID]:session:_zcr_complete_sessions' \
        '(-c --continue)'{-c,--continue}'[Continue most recent conversation]' \
        '--dangerously-skip-permissions[Bypass all permission checks]' \
        '--allow-dangerously-skip-permissions[Enable bypass option without default]' \
        '(-p --print)'{-p,--print}'[Print response and exit]' \
        '--model[Model for the session]:model:(opus sonnet haiku claude-opus-4-6 claude-sonnet-4-6 claude-haiku-4-5-20251001)' \
        '--chrome[Enable Chrome integration]' \
        '--no-chrome[Disable Chrome integration]' \
        '(-w --worktree)'{-w,--worktree}'[Create git worktree for session]::name:' \
        '(-n --name)'{-n,--name}'[Set display name for session]:name:' \
        '--permission-mode[Permission mode]:mode:(acceptEdits bypassPermissions default dontAsk plan auto)' \
        '--effort[Effort level]:level:(low medium high max)' \
        '(-d --debug)'{-d,--debug}'[Enable debug mode]::filter:' \
        '--add-dir[Additional directories]:directory:_directories' \
        '--mcp-config[MCP server config]:config:_files' \
        '--system-prompt[System prompt]:prompt:' \
        '--append-system-prompt[Append system prompt]:prompt:' \
        '(-h --help)'{-h,--help}'[Display help]' \
        '(-v --version)'{-v,--version}'[Show version]' \
        '*:prompt:'
}

# ─── Setup ──────────────────────────────────────────────────────────────────────

# Detect common flags
_zcr_detect_flags

# Prepend our strategy to zsh-autosuggestions
if [[ -n "$ZSH_AUTOSUGGEST_STRATEGY" ]] || (( ${+functions[_zsh_autosuggest_strategy_default]} )); then
    ZSH_AUTOSUGGEST_STRATEGY=(claude_resume "${ZSH_AUTOSUGGEST_STRATEGY[@]}")
fi

# Register completion
compdef _zcr_complete_claude claude
