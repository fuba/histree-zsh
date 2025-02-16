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
mkdir -p "${TARGET_DIR}/core"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    print_error "Go is required to build histree-core. Please install Go first."
fi

# Install histree-core in the target directory
print_step "Installing histree-core..."
if [ -d "${TARGET_DIR}/core/.git" ]; then
    print_step "Updating existing histree-core..."
    (cd "${TARGET_DIR}/core" && git pull) || print_error "Failed to update histree-core"
else
    print_step "Cloning histree-core..."
    rm -rf "${TARGET_DIR}/core"  # Remove directory if it exists but is not a git repo
    git clone https://github.com/fuba/histree-core.git "${TARGET_DIR}/core" || print_error "Failed to clone histree-core"
fi

# Build histree-core using make
print_step "Building histree-core..."
(cd "${TARGET_DIR}/core" && make) || print_error "Failed to build histree-core"

# Copy the zsh plugin
print_step "Installing zsh plugin..."
cp "${SCRIPT_DIR}/histree.zsh" "${TARGET_DIR}/" || print_error "Failed to copy histree.zsh"

# Add configuration to .zshrc if not already present
ZSHRC="${HOME}/.zshrc"
SOURCE_LINE="source ${TARGET_DIR}/histree.zsh"

# Default configurations
DB_CONFIG="export HISTREE_DB=\"\${HOME}/.histree.db\""
LIMIT_CONFIG="export HISTREE_LIMIT=100"
PATH_CONFIG="export PATH=\"\${HOME}/.histree-zsh/core/bin:\${PATH}\""

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
