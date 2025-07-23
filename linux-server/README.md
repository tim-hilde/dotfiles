# Linux Server Dotfiles

A minimal, fast-installing configuration for Linux servers that provides essential development tools without the bloat.

## Features

### 🚀 **Fast Installation**
- Uses system package managers (apt/dnf/pacman)
- Minimal dependencies
- No heavy frameworks or themes

### 🛠️ **Essential Tools**
- **Shell**: Zsh with oh-my-zsh and essential plugins
- **Prompt**: Starship (fast and informative)
- **Editor**: Neovim with minimal but powerful config
- **Terminal Multiplexer**: Tmux with server-optimized settings
- **File Navigation**: eza (modern ls), zoxide (smart cd), fzf
- **Text Processing**: bat (better cat), ripgrep, jq
- **Development**: git, direnv, python3

### 📁 **Included Configurations**
- Zsh with syntax highlighting and autosuggestions
- Tmux with sensible server defaults (Ctrl+a prefix)
- Neovim with essential keybindings and file type support
- Git with useful aliases and colors
- Starship prompt with server-relevant information
- Comprehensive aliases for server administration

## Installation

### Quick Install
```bash
# Clone the main dotfiles repo
git clone https://github.com/your-username/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Run the server installation
./linux-server/install.sh
```

### Manual Install
```bash
# From the dotfiles root directory
./install linux-server
```

## What Gets Installed

### System Packages
- **Core**: zsh, git, curl, wget, tmux, neovim
- **Languages**: python3, python3-pip
- **Tools**: fd-find, ripgrep, fzf, jq, tree, htop
- **Utilities**: direnv, bat, unzip, build-essential

### Additional Tools
- **eza**: Modern replacement for ls
- **zoxide**: Smart cd command
- **starship**: Fast shell prompt
- **oh-my-zsh**: Zsh framework with essential plugins

## Key Features

### Tmux Configuration
- Prefix key: `Ctrl+a` (easier on servers)
- Vim-style pane navigation
- Mouse support enabled
- Clean status bar with essential info

### Neovim Setup
- Leader key: `Space`
- Essential key mappings for navigation and editing
- Basic syntax highlighting
- Auto-removal of trailing whitespace
- File type specific indentation

### Shell Aliases
- Modern tool replacements (`ls` → `eza`, `cd` → `zoxide`)
- Git shortcuts (`gs`, `ga`, `gc`, etc.)
- System administration helpers
- Docker shortcuts (if docker installed)
- Quick navigation aliases

### Starship Prompt
- Shows username@hostname for SSH sessions
- Git branch and status
- Python/Node.js version when relevant
- Docker context when active
- Command duration for long-running commands

## Customization

### Local Overrides
Create `~/.zshrc.local` for machine-specific configurations that won't be overwritten.

### Git Configuration
Update with your details:
```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

## Supported Distributions

This configuration works on:
- **Ubuntu/Debian** (apt)
- **RHEL/CentOS/Fedora** (dnf)
- **Arch Linux** (pacman)

## Performance

- **Startup time**: < 100ms for new shell sessions
- **Memory usage**: Minimal overhead
- **Package count**: ~20 essential packages
- **Installation time**: 2-5 minutes depending on connection

## Troubleshooting

### Missing Packages
If some packages aren't available on your distribution:
- eza: Falls back to standard ls with colors
- bat: Falls back to standard cat
- fd: Falls back to standard find

### Font Issues
If icons don't display properly:
- Install a Nerd Font or disable icons in eza
- Starship works without special fonts

### Permission Issues
If installation fails with permission errors:
- Ensure sudo access for package installation
- Some commands may need manual execution

## Philosophy

This configuration follows these principles:
1. **Speed over features**: Fast startup and minimal bloat
2. **Reliability**: Works across different Linux distributions
3. **Productivity**: Essential tools for server administration
4. **Simplicity**: Easy to understand and modify
5. **Security**: Minimal attack surface, no unnecessary services

Perfect for development servers, production environments, and remote Linux systems where you need a productive environment without the overhead.