# About this project

{{cookiecutter.description}}

# Getting started

## Installation

### 1. Install Pyenv

```shel
curl https://pyenv.run | bash
```

### 2. Install Python 3.10.6

```shel
pyenv install 3.10.6 && pyenv local 3.10.6
```

### 3. Install Poetry

```sh
curl -sSL https://install.python-poetry.org | python3 -
```

### 4. Install the poetry environment

```sh
cd {{cookiecutter.repo_name}}
poetry install
```

### 5. Activate poetry environment

On linux/mac:

```sh
source $(poetry env info --path)/bin/activate
```

On windows:

```powershell
& ((poetry env info --path) + "\Scripts\activate.ps1")
```
