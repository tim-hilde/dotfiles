.DEFAULT_GOAL := default
#################### PACKAGE ACTIONS ###################

make_create_pyenv:
	@if pyenv virtualenvs | grep -q "{{cookiecutter.package_name}}"; then \
		echo "Virtual environment "{{cookiecutter.package_name}}" already exists."; \
	else \
		pyenv virtualenv {{cookiecutter.package_name}}; \
	fi
	@pyenv local {{cookiecutter.package_name}}

make install:
	@pip install --upgrade pip
	@pip install -e .

reinstall_package:
	@pip uninstall -y {{cookiecutter.package_name}} || :
	@pip install -e .
