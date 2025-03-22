function init_(){
    local env=${1:-}

    if ! inside_ > /dev/null 2>&1; then
        log_ "Initializing the application..."
        echo "[project]
name = \"<project-name>\"
version = \"0.0.0\"
description = \"<project-description>\"
readme = \"README.md\"
requires-python = \">=3.9\"
license = {text = \"<project-license>\"}
authors = [
    {name = \"<your_name>\", email = \"<your@email.com>\"},
]

[build-system]
requires = [\"setuptools>=61.0\", \"wheel\"]
build-backend = \"setuptools.build_meta\"

[tool.setuptools.packages.find]
where = [\".\"]
include = [\"<project-name>*\"]
" >> $PWD/pyproject.toml
    fi
    venv=$(venv_ "$env")   
    if has_venv_ $env; then
        error_ "The environment '$(env_ $env)' was already initialized."
        return 1
    else
        log_ "Initializing environment '$(env_ $env)'..."
        python3 -m venv "$venv"
        gitgnore=$(find_ file .gitignore)
        if [[ -z "$gitignore" ]]; then
            touch .gitignore
        fi
        for ignore in ${PY_IGNORE[@]}; do
            if ! grep -qx "$ignore" .gitignore; then
                echo "$ignore" >> .gitignore
            fi 
        done
        if ! grep -qx "${venv##*/}" .gitignore; then
            echo "${venv##*/}" >> .gitignore
        fi
        done_ "The environment '$(env_ $envs)' has been initalized."
    fi
}
