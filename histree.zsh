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

_histree_reverse_array() {
    local -a input_array
    input_array=("$@")
    local -a reversed_array=()
    local i
    for ((i=${#input_array[@]}; i>=1; i--)); do
        reversed_array+=("${input_array[i]}")
    done
    print -r -l -- "${reversed_array[@]}"
}

_histree_collect_histree_entries() {
    local output
    output=$(command histree-core -db "$HISTREE_DB" -action get \
        -limit "$HISTREE_LIMIT" \
        -dir "$PWD" \
        -format simple 2>/dev/null)
    local -a entries
    entries=()
    local line
    while IFS= read -r line; do
        entries+=("$line")
    done <<< "$output"
    _histree_reverse_array "${entries[@]}"
}

_histree_collect_zsh_entries() {
    local -a entries
    entries=()
    local line
    while IFS= read -r line; do
        entries+=("$line")
    done < <(fc -l -n 1 2>/dev/null)
    print -r -l -- "${entries[@]}"
}

_histree_incremental_search() {
    emulate -L zsh
    setopt no_aliases

    local direction="$1"
    local original_buffer="$BUFFER"
    local query=""
    local -a histree_entries zsh_entries matches pool
    histree_entries=("${(@f)$(_histree_collect_histree_entries)}")
    zsh_entries=("${(@f)$(_histree_collect_zsh_entries)}")

    local last_query=""
    local last_source=""
    local source="histree"
    local idx=0
    local current=""
    local key=""
    local last_message=""

    while true; do
        if [[ "$query" == *"~/"* ]]; then
            source="zsh-history"
            pool=("${zsh_entries[@]}")
        else
            source="histree"
            pool=("${histree_entries[@]}")
        fi

        if [[ "$query" != "$last_query" || "$source" != "$last_source" ]]; then
            matches=()
            if [[ -n "$query" ]]; then
                local entry
                for entry in "${pool[@]}"; do
                    if print -r -- "$entry" | command grep -F -q -- "$query"; then
                        matches+=("$entry")
                    fi
                done
            else
                matches=("${pool[@]}")
            fi

            if (( ${#matches[@]} > 0 )); then
                if [[ "$direction" == "backward" ]]; then
                    idx=${#matches[@]}
                else
                    idx=1
                fi
            else
                idx=0
            fi

            last_query="$query"
            last_source="$source"
        fi

        if (( idx > 0 )); then
            current="${matches[idx]}"
            BUFFER="$current"
            CURSOR=${#BUFFER}
        else
            BUFFER="$original_buffer"
            CURSOR=${#BUFFER}
        fi

        local message="histree ${direction} search (${source}): ${query}"
        if [[ "$message" != "$last_message" ]]; then
            zle -M "$message"
            last_message="$message"
        fi
        zle -R

        IFS= read -rs -k1 key
        case "$key" in
            $'\r'|$'\n')
                zle -M ""
                return 0
                ;;
            $'\x1b'|$'\x03'|$'\x07')
                BUFFER="$original_buffer"
                CURSOR=${#BUFFER}
                zle -M ""
                return 0
                ;;
            $'\x7f'|$'\b')
                if [[ -n "$query" ]]; then
                    query="${query[1,-2]}"
                fi
                ;;
            $'\x12')
                direction="backward"
                if (( ${#matches[@]} > 0 && idx > 1 )); then
                    idx=$((idx - 1))
                fi
                ;;
            $'\x13')
                direction="forward"
                if (( ${#matches[@]} > 0 && idx < ${#matches[@]} )); then
                    idx=$((idx + 1))
                fi
                ;;
            *)
                if [[ "$key" != $'\t' ]]; then
                    query+="$key"
                fi
                ;;
        esac
    done
}

histree-incremental-search-backward() {
    _histree_incremental_search backward
}

histree-incremental-search-forward() {
    _histree_incremental_search forward
}

zle -N histree-incremental-search-backward
zle -N histree-incremental-search-forward
bindkey '^R' histree-incremental-search-backward
bindkey '^S' histree-incremental-search-forward
