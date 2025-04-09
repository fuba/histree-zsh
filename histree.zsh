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
