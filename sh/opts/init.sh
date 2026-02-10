function init_(){
    local root
    root=$(find_ root 2>/dev/null)

    if [[ -z "$root" ]]; then
        root="$PWD"
        log_ "Initializing Python project in '$root'..."
        local project_name
        project_name="$(basename "$root")"

        cat > "$root/pyproject.toml" <<EOF
[project]
name = "$project_name"
version = "0.0.0"
description = ""
readme = "README.md"
requires-python = ">=3.9"
license = {text = "MIT"}
authors = [
    {"name" = "Your Name", "email" = "you@email.com"},
]
dependencies = [
]

[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[tool.setuptools.packages.find]
where = ["."]
include = ["${project_name}*"]
EOF
    else
        log_ "Using existing Python project at '$root'."
    fi

    if [[ ! -f "$root/.env" ]]; then
        touch "$root/.env"
        done_ "Created '.env'."
    fi

    if [[ ! -f "$root/requirements.txt" ]]; then
        touch "$root/requirements.txt"
        done_ "Created 'requirements.txt'."
    fi

    if [[ ! -d "$root/$project_name" ]]; then
        mkdir "$root/$project_name"
        touch "$root/$project_name/__init__.py"
        done_ "Created project directory."
    fi

    local venv
    venv=$(venv_) || {
        error_ "Unable to determine project root for virtual environment."
        return 1
    }

    if has_venv_; then
        warn_ "The virtual environment '.venv' already exists."
    else
        log_ "Creating virtual environment '.venv'..."
        python3 -m venv "$venv"
        if [[ $? -ne 0 ]]; then
            error_ "Failed to create virtual environment."
            return 1
        fi
        done_ "Virtual environment '.venv' has been created."
    fi

    local gitignore_path="$root/.gitignore"
    if [[ ! -f "$gitignore_path" ]]; then
        touch "$gitignore_path"
    fi
    for ignore in "${PY_IGNORE[@]}"; do
        if ! grep -qx "$ignore" "$gitignore_path"; then
            echo "$ignore" >> "$gitignore_path"
        fi 
    done
    if ! grep -qx ".venv" "$gitignore_path"; then
        echo ".venv" >> "$gitignore_path"
    fi
    log_ "Installing the project in edit mode..."
    $venv/bin/pip install -e . > /dev/null 2>&1
    rm -r $root/$project_name.egg-info
    done_ "The project '$project_name' has been initialized."
}

