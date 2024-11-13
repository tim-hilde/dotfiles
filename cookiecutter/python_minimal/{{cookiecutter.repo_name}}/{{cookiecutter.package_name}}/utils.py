import os


def get_root_path() -> str:
    """Automatically detect the full path leading to the repo folder.
    Assuming directory structure is:
            /this/project/path/repo_name/package/this_module.py
    Return:
            /path/to/this/project/repo_name
    """
    module_path = os.path.abspath(__file__)
    package_path = os.path.dirname(module_path)
    repo_path = os.path.dirname(package_path)
    return repo_path


def get_project_path(*lower_paths):
    """If repo directory is
            `/path/to/repo/project`
    and `lower_paths` is `file.txt`
    then return
            `/path/to/repo/project/file.txt`

    Alternatively, if `lower_paths` is ["subfolder", "file.txt"]
    then return
            `/path/to/repo/project/subfolder/file.txt`
    etc for any number of subfolder layers.
    """
    root = get_root_path()
    path = os.path.join(root, *lower_paths)
    return path
