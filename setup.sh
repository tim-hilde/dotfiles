#!/bin/zsh

# Prompt the user and set the VM variable
while true; do
  read "choice?Is this a virtual machine? (y/n): "
  if [[ "$choice" =~ [Yy] ]]; then
    VM=true; break
  else
    VM=false; break
  fi
done

echo "Installing packages"
# install oh my zsh
yes | sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/pyenv/pyenv.git ~/.pyenv
git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv

cat << EOF >> ~/.zprofile
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
EOF

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# you should use
git clone https://github.com/fdellwing/zsh-bat.git $ZSH_CUSTOM/plugins/zsh-bat
# you should use
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
# zoxide
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
eval "$(zoxide init zsh)"

if [ "$VM" = false ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
yes | ~/.fzf/install

sh symlinking.sh
