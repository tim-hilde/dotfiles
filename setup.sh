#!/bin/bash

set -e  # Exit on error
set -u  # Exit on undefined variable

DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_REPO="https://github.com/tim-hilde/dotfiles.git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if dotfiles already exist
if [ -d "$DOTFILES_DIR" ]; then
    echo_warning "Dotfiles directory already exists at $DOTFILES_DIR"
	echo_error "Installation cancelled"
	exit 1
fi

# System type selection with validation
echo "Select your system type:"
PS3="Enter your choice (1-2): "
options=("mac" "server")

select system_type in "${options[@]}"; do
    if [ -n "$system_type" ]; then
        echo_info "You selected: $system_type"
        break
    else
        echo_error "Invalid selection. Please choose 1 or 2."
    fi
done

# Confirm selection
read -p "Continue with '$system_type' configuration? (Y/n): " -r
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo_error "Installation cancelled"
    exit 0
fi

# Clone repository
echo_info "Cloning dotfiles repository..."
if ! git clone "$DOTFILES_REPO" "$DOTFILES_DIR"; then
    echo_error "Failed to clone repository"
    exit 1
fi

# Change to dotfiles directory
cd "$DOTFILES_DIR" || {
    echo_error "Failed to change to dotfiles directory"
    exit 1
}

# Check if install script exists
if [ ! -f "./install" ]; then
    echo_error "Install script not found in dotfiles repository"
    exit 1
fi

# Make install script executable if needed
if [ ! -x "./install" ]; then
    chmod +x "./install"
fi

# Run installation
echo_info "Running installation for $system_type..."
if ./install "$system_type"; then
    echo_info "Installation completed successfully!"
else
    echo_error "Installation failed"
    exit 1
fi
