#!/usr/bin/env zsh

# Set default configuration paths and values
HISTREE_DB="${HISTREE_DB:-$HOME/.histree.db}"
HISTREE_LIMIT="${HISTREE_LIMIT:-100}"
HISTREE_HOSTNAME="${HOST:=$(hostname)}"

# Check if histree-core binary is available in PATH
if ! command -v histree-core &> /dev/null; then
    echo "Error: histree-core binary not found. Please ensure ~/.histree-zsh/bin is in your PATH"
    return 1
fi

# Store process ID when the plugin is loaded
typeset -g _HISTREE_LAST_CMD
typeset -g _HISTREE_LAST_EXIT_CODE

# Function to add a command to history
_histree_add_command() {
    local cmd="$_HISTREE_LAST_CMD"
    local exit_code="$_HISTREE_LAST_EXIT_CODE"

    # If the command is empty or starts with a space, do not record it
    [[ -z "$cmd" || "$cmd" =~ ^[[:space:]] ]] && return

    echo "$cmd" | command histree-core -db "$HISTREE_DB" -action add \
        -dir "$PWD" \
        -hostname "$HISTREE_HOSTNAME" \
        -pid $$ \
        -exit "$exit_code"
}

# Function to capture the last command
_histree_preexec() {
    _HISTREE_LAST_CMD="$1"
}

# Function to capture the last exit code
_histree_precmd() {
    _HISTREE_LAST_EXIT_CODE="$?"
    _histree_add_command
}

# Hook into zsh pre-execution and pre-command
autoload -Uz add-zsh-hook
add-zsh-hook preexec _histree_preexec
add-zsh-hook precmd _histree_precmd

# Widget to run an incremental history search using histree data
_histree_incremental_search() {
    emulate -L zsh
    setopt localoptions no_aliases

    local tmpfile
    tmpfile="$(mktemp -t histree-zsh.XXXXXX)" || return 1

    local -a histree_lines=()
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        histree_lines+=("$line")
    done < <(
        command histree-core -db "$HISTREE_DB" -action get \
            -limit "$HISTREE_LIMIT" \
            -dir "$PWD" \
            -format simple
    )

    for line in "${(O)histree_lines[@]}"; do
        print -r -- ": 0:0;$line"
    done > "$tmpfile"

    fc -p
    fc -R "$tmpfile"
    zle history-incremental-search-backward
    local histree_search_status=$?
    fc -P

    rm -f "$tmpfile"
    return $histree_search_status
}

zle -N histree-incremental-search _histree_incremental_search

HISTREE_INCREMENTAL_SEARCH_KEY="${HISTREE_INCREMENTAL_SEARCH_KEY:-^[[82;6u}"
HISTREE_INCREMENTAL_SEARCH_KEYMAP="${HISTREE_INCREMENTAL_SEARCH_KEYMAP:-all}"

if [[ -n "$HISTREE_INCREMENTAL_SEARCH_KEY" ]]; then
    if [[ "$HISTREE_INCREMENTAL_SEARCH_KEYMAP" == "all" ]]; then
        bindkey -M emacs "$HISTREE_INCREMENTAL_SEARCH_KEY" histree-incremental-search
        bindkey -M viins "$HISTREE_INCREMENTAL_SEARCH_KEY" histree-incremental-search
    else
        bindkey -M "$HISTREE_INCREMENTAL_SEARCH_KEYMAP" \
            "$HISTREE_INCREMENTAL_SEARCH_KEY" histree-incremental-search
    fi
fi

bindkey -M isearch '^M' accept-line

# Function to display history or update paths
function histree {
    local format="simple"
    local action="get"
    local old_path=""
    local new_path=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                format="verbose"
                shift
                ;;
            -json|--json)
                format="json"
                shift
                ;;
            -u|--update-path)
                action="update-path"
                shift
                if [[ $# -ge 2 ]]; then
                    old_path="$1"
                    new_path="$2"
                    shift 2
                else
                    echo "Error: -u|--update-path requires two arguments: <old_path> <new_path>"
                    return 1
                fi
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ "$action" == "get" ]]; then
        command histree-core -db "$HISTREE_DB" -action get \
            -limit "$HISTREE_LIMIT" \
            -dir "$PWD" \
            -format "$format"
    elif [[ "$action" == "update-path" ]]; then
        command histree-core -db "$HISTREE_DB" -action update-path \
            -old-path "$old_path" \
            -new-path "$new_path"
    fi
}
