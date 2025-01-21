# About

`py` is a simple script made in pure `bash` designed to work as a Python project manager, being a lightweight a minimalist replacement for `poetry` and `uv`, `pyenv`, etc.

# Why

Because direct manipulation of `venvs` and `pip` sucks, but adding a new dependency sucks more.

# Usage

```
USAGE:
    py [action] [flags]

ACTIONS:
    I, init ................. initialize an environment
    R, reinit ............... re-initialize an environment
    a, add  ................. add dependencies to a requirements file
    d, del, delete .......... delete dependencies from a requirements file
    i, ins, install ......... install packages
    u, uns, uninstall ....... uninstall packages
    U, up, update ........... update packages
    x, exec, run ............ execute some file or command

FLAGS:
    -f, --from .................... exec action from somewhere
    -t, --to ...................... exec action into somewhere
    -e, --env, --environment ...... exec action in some environment
    -r, --reg, --registry ......... exec action for some registry
    -R, --rec, --recursive ........ exec action recursively
    -p, --path .................... exec action from some path 
```

# Examples

```bash
# initialize an environment
py init my_env
# add some deps to a requirements file of some environment
py add my_dep other_dep --to/--env  my_env
# delete some dep from a requirements file
py del my_dep other_dep --from/--env my_env
py del my_dep other_dep --path /path/to/some/file.txt
# install packages (similar for uninstall and update packages)
py ins my_pkg other_pkg --from/--reg my_registry --to/--env my_env 
py ins --recursive --env some_env
py ins --recursive --path /path/to/some/file.txt
# execute some file or some command
py exec /path/to/file.py --from/--env my_env
py exec some_command --from/--env my_env
```

# Remarks

1. If the environment is not passed, it is assumed the `main` environment, for which:
    1. the virtual env is `.venv`
    2. the requirements file is `requirements.txt`
    3. the envs file is `.env`
2. If the registry is not passed, it is assumed PyPi
