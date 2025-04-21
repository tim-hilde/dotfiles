#!/usr/bin/env python
import json
import os

cookiecutter_file = os.path.join(os.path.dirname(os.getcwd()), 'cookiecutter.json')

with open(cookiecutter_file, 'r') as f:
    cookiecutter_data = json.load(f)

while cookiecutter_data['add_another_author'] == 'yes':
    name = input("Author name: ")
    email = input("Author email: ")

    new_author = {
        "name": name,
        "email": email
    }

    cookiecutter_data['authors'].append(new_author)
    cookiecutter_data['add_another_author'] = input("Add another author? (yes/no): ")

with open(cookiecutter_file, 'w') as f:
    json.dump(cookiecutter_data, f, indent=2)

# Run uv sync in the project directory
try:
    print("Running uv sync...")
    subprocess.run(["uv", "sync"], check=True)
    print("uv sync completed successfully.")
except subprocess.CalledProcessError:
    print("Error: Failed to run uv sync.")
except FileNotFoundError:
    print("Error: uv command not found. Please ensure uv is installed and in your PATH.")
