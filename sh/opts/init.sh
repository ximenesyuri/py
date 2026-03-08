function init_(){
    local root
    root=$(find_ root 2>/dev/null)

    local project_name=""
    local pyproject=""

    if [[ -z "$root" ]]; then
        root="$PWD"
        log_ "Initializing Python project in '$root'..."
        project_name="$(basename "$root")"
        pyproject="$root/pyproject.toml"

        cat > "$pyproject" <<EOF
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
        pyproject="$root/pyproject.toml"
        if [[ -f "$pyproject" ]]; then
            project_name=$(awk -F' = ' '
                /^[[:space:]]*name[[:space:]]*=/ {
                    val = $2
                    gsub(/^[ "]*/, "", val)
                    gsub(/[ ",]*/, "", val)
                    print val
                    exit
                }
            ' "$pyproject")
        fi
        project_name=${project_name:-"$(basename "$root")"}
    fi

    [[ -f "$root/.env" ]] || { touch "$root/.env"; done_ "Created '.env'."; }
    [[ -f "$root/requirements.txt" ]] || { touch "$root/requirements.txt"; done_ "Created 'requirements.txt'."; }

    if [[ -n "$project_name" && ! -d "$root/$project_name" ]]; then
        mkdir "$root/$project_name"
        touch "$root/$project_name/__init__.py"
        done_ "Created project directory '$project_name'."
    fi

    local envdir sitedir
    envdir=$(env_dir_) || {
        error_ "Unable to determine environment directory."
        return 1
    }
    sitedir=$(site_dir_) || {
        error_ "Unable to determine site-packages directory."
        return 1
    }

    if [[ -d "$sitedir" ]]; then
        warn_ "Environment directory already exists at '$envdir'."
    else
        mkdir -p "$sitedir"
        done_ "Created environment directory at '$envdir' (site-packages: '$sitedir')."
    fi

    local gitignore_path="$root/.gitignore"
    [[ -f "$gitignore_path" ]] || touch "$gitignore_path"
    for ignore in "${PY_IGNORE[@]}"; do
        if ! grep -qx "$ignore" "$gitignore_path"; then
            echo "$ignore" >> "$gitignore_path"
        fi 
    done
    if ! grep -qx ".venv" "$gitignore_path"; then
        echo ".venv" >> "$gitignore_path"
    fi

    if [[ ! -f "$pyproject" ]]; then
        error_ "pyproject.toml not found; cannot determine packages to link."
        return 1
    fi

    local include_str
    include_str=$(awk '
        /^\[tool\.setuptools\.packages\.find\]/ { in_find=1; next }
        /^\[/ && in_find { exit }  # next table -> stop
        in_find && /^[[:space:]]*include[[:space:]]*=/ {
            line = $0
            sub(/^[^[]*\[/, "", line)      # to first [
            sub(/\].*$/, "", line)         # from closing ] on
            gsub(/"/, "", line)
            gsub(/[[:space:]]*,[[:space:]]*/, " ", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            print line
            exit
        }
    ' "$pyproject")

    local patterns=()
    if [[ -n "$include_str" ]]; then
        patterns=($include_str)
    else
        patterns=("${project_name}*")
    fi

    if [[ ${#patterns[@]} -eq 0 ]]; then
        warn_ "No [tool.setuptools.packages.find.include] patterns found; nothing to link."
    else
        log_ "Linking packages into '$sitedir' using patterns: ${patterns[*]}"
    fi

    local entry base pat matched
    for entry in "$root"/*; do
        [[ -d "$entry" ]] || continue
        base=$(basename "$entry")

        case "$base" in
            dist|build|.venv*|.git|__pycache__|*.egg-info)
                continue
                ;;
        esac

        matched=false
        for pat in "${patterns[@]}"; do
            if [[ "$base" == $pat ]]; then
                matched=true
                break
            fi
        done
        $matched || continue

        if [[ ! -f "$entry/__init__.py" ]]; then
            warn_ "Directory '$base' matches include pattern but has no __init__.py; skipping."
            continue
        fi

        if [[ -L "$sitedir/$base" ]]; then
            log_ "Symlink for '$base' already exists in site-packages; skipping."
            continue
        elif [[ -e "$sitedir/$base" ]]; then
            warn_ "Cannot create symlink for '$base': '$sitedir/$base' already exists (not a symlink)."
            continue
        fi

        ln -s "$entry" "$sitedir/$base"
        done_ "Linked package '$base' into site-packages."
    done

    done_ "The project '$project_name' has been initialized (target+PYTHONPATH model)."
}

