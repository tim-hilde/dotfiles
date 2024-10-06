# About this project

{{cookiecutter.description}}

# Getting started

## Prerequisites
The following are prerequisites to run this codebase:
 - Python
 - Poetry


 ## Installation
### 1. Install the poetry environment

```sh
cd {{cookiecutter.repo_name}}
poetry install
```

### 2. Activate poetry environment

On linux/mac:
```sh
source $(poetry env info --path)/bin/activate
```

On windows:
```powershell
& ((poetry env info --path) + "\Scripts\activate.ps1")
```
