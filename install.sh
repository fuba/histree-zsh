#!/usr/bin/env bash
set -e

# Determine the installation directory
TARGET_DIR="${HOME}/.histree-zsh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print current step with color
print_step() {
    echo -e "\033[0;34m=> $1\033[0m"
}

# Print error with color
print_error() {
    echo -e "\033[0;31mError: $1\033[0m"
    exit 1
}

print_step "Installing histree-zsh..."

# Create target directory structure
mkdir -p "${TARGET_DIR}/bin"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    print_error "Go is required to install histree-core. Please install Go first."
fi

# Install histree-core using go install (recommended method)
print_step "Installing histree-core using Go..."
go install github.com/fuba/histree-core/cmd/histree-core@latest || print_error "Failed to install histree-core"

# Find histree-core binary
HISTREE_CORE_BIN=""
if command -v histree-core &> /dev/null; then
    HISTREE_CORE_BIN=$(command -v histree-core)
    print_step "Found histree-core binary at: ${HISTREE_CORE_BIN}"
    
    # Copy to our bin directory, but don't error if it's the same file
    if [ "${HISTREE_CORE_BIN}" != "${TARGET_DIR}/bin/histree-core" ]; then
        cp "${HISTREE_CORE_BIN}" "${TARGET_DIR}/bin/" || print_error "Failed to copy histree-core binary"
    fi
else
    print_error "Could not find histree-core binary after installation. Check your GOPATH and PATH settings."
fi

# Make sure the binary is executable
chmod +x "${TARGET_DIR}/bin/histree-core" || print_error "Failed to make histree-core executable"

# Copy the zsh plugin
print_step "Installing zsh plugin..."
cp "${SCRIPT_DIR}/histree.zsh" "${TARGET_DIR}/" || print_error "Failed to copy histree.zsh"

# Add configuration to .zshrc if not already present
ZSHRC="${HOME}/.zshrc"
SOURCE_LINE="source ${TARGET_DIR}/histree.zsh"

# Default configurations
DB_CONFIG="export HISTREE_DB=\"\${HOME}/.histree.db\""
LIMIT_CONFIG="export HISTREE_LIMIT=100"
PATH_CONFIG="export PATH=\"\${HOME}/.histree-zsh/bin:\${PATH}\""

if grep -qF "$SOURCE_LINE" "${ZSHRC}"; then
    print_step "Your .zshrc already sources histree-zsh"
else
    print_step "Adding configuration to ${ZSHRC}..."
    {
        echo ""
        echo "# histree-zsh configuration"
        echo "$PATH_CONFIG"
        echo "$DB_CONFIG"
        echo "$LIMIT_CONFIG"
        echo "$SOURCE_LINE"
    } >> "${ZSHRC}" || print_error "Failed to update .zshrc"
    echo "Added configuration to ${ZSHRC}"
fi

echo -e "\033[0;32mInstallation complete!\033[0m"
echo "Please restart your terminal or run: source ~/.zshrc"
