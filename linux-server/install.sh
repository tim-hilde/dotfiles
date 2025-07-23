# Linux Server Installation Script
#!/bin/bash

set -e

echo "🚀 Installing minimal Linux server dotfiles..."
echo "================================================="

# Check if dotbot is available
if [[ ! -d "dotbot" ]]; then
    echo "Error: dotbot directory not found. Please run this from the dotfiles root directory."
    exit 1
fi

# Run the linux-server configuration
./install linux-server

echo ""
echo "✅ Installation complete!"
echo ""
echo "📋 What was installed:"
echo "  • Essential CLI tools (git, tmux, neovim, bat, eza, fzf, etc.)"
echo "  • Zsh with oh-my-zsh and minimal plugins"
echo "  • Starship prompt (fast and minimal)"
echo "  • Optimized tmux configuration"
echo "  • Minimal neovim setup with essential keybindings"
echo "  • Useful aliases for server administration"
echo ""
echo "🔧 Post-installation steps:"
echo "  1. Update git config with your name/email:"
echo "     git config --global user.name 'Your Name'"
echo "     git config --global user.email 'your@email.com'"
echo ""
echo "  2. Restart your shell or run: exec zsh"
echo ""
echo "  3. Optional: Install additional tools as needed:"
echo "     • htop/btop for system monitoring"
echo "     • lazygit for git management"
echo "     • docker for containerization"
echo ""
echo "💡 Tips:"
echo "  • Use 'Ctrl+a' as tmux prefix"
echo "  • Leader key in nvim is 'Space'"
echo "  • Type 'alias' to see all available shortcuts"
echo ""
echo "Happy server administration! 🎉"