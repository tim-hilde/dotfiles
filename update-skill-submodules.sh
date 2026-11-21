#!/usr/bin/env zsh
export GIT_OPTIONAL_LOCKS=0
export PATH=/usr/local/lib:/usr/local/bin:/opt/homebrew/bin/:$PATH
cd "$(dirname "$0")" || return 1

git submodule update --init --remote --merge -- opencode/skills
