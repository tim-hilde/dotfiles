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

# General documentation

## `data` vs `static` directories

The `data` directory is for storing raw data, processed data (produced by this code but not final) and output data.
The contents of these folders should not be tracked by git,
because they may contain sensitive information and may be large in size.

The `static` directory is for static (unchanging) data that is needed for the code to run and is not sensitive,
such as lookup tables. These need to be shared between developers using the code, and should be tracked by git.
