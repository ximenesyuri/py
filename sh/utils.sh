find_() {
    local kind=$1
    local to_find=$2
    local dir=$PWD

    while [[ "$dir" != "/" ]]; do
        case $kind in 
            f|file)
                if [[ -f "$dir/$to_find" ]]; then
                    echo "$dir/$to_find"
                    return 0
                fi
                dir=$(dirname "$dir")
                continue
                ;;
            d|dir)
                if [[ -d "$dir/$to_find" ]]; then
                    echo "$dir/$to_find"
                    return 0
                fi
                dir=$(dirname "$dir")
                continue
                ;;
            r|root)
                if [[ -f "$dir/pyproject.toml" ]]; then
                    echo "$dir"
                    return 0
                fi
                dir=$(dirname "$dir")
                continue
                ;;
            *)
                echo "error: find_: option not valid: '$kind'."
                return 1
                ;;
        esac
    done
    return 1
}

function match_(){
    if [[ -f "$2" ]]; then
        if [[ -n "$(grep -E ^$1$ $2)" ]]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

function inside_(){
    if [[ -n "$(find_ root)" ]]; then
        return 0
    else
        error_ "You are not in an Python initialized directory."
        info_ "Try 'py init [env]'."
        return 1
    fi
}

function env_(){
    if [[ -z "$2" ]]; then
        if [[ -n "$1" ]]; then
            echo "$1"
        else
            echo "main"
        fi
    else
        error_ "Unexpected arguments: '${@:2}'."
        return 1
    fi
}

function venv_(){
    local env="$1"
    local root=$(find_ root)
    if [[ -n "$root" ]]; then
        echo "${root}/.venv${env:+.${env}}"
        return 0
    else
        return 1
    fi
}

function has_venv_() {
    local env="$1"
    if [[ -d "$(venv_ $env)" ]]; then
            return 0
    fi 
        return 1
}

function has_registry_() {
    local registry_name="$1"
    local root
    root=$(find_ root)
    for file in "$root/py.yml" "$root/py.yaml"; do
        if [[ -f "$file" ]]; then
            if yq e ".registries | has(\"$registry_name\")" "$file" > /dev/null; then
                return 0
            fi
        fi
    done
    local config_file
    if [[ -n "$PY_CONFIG" && -f "$PY_CONFIG" && "$PY_CONFIG" == *.yml ]]; then
        config_file="$PY_CONFIG"
    else
        config_file="${BASH_SOURCE[0]%/*}/../yml/py.yml"
    fi
    if [[ -f "$config_file" ]]; then
        if yq e ".registries | has(\"$registry_name\")" "$config_file" > /dev/null; then
            return 0
        fi
    fi
    error_ "Registry '$registry_name' not found in configuration files."
    return 1
}


function is_file_() {
    local path="$1"
    [[ -f "$path" ]]
}

function is_txt_() {
    local file="$1"
    [[ "$file" == *.txt ]]
}

function req_(){
    root=$(find_ root)
    if [[ -n "$root" ]]; then
        echo "$root/requirements${env:+.${env}}.txt"
        return 0
    else
        return 1
    fi
}

function activate_() {
    local env="$1"
    local root=$(find_ root)
    local venv="${root}/.venv${env:+.${env}}"

    if [[ -d "$venv" ]]; then
        source "$venv/bin/activate"
    else
        error_ "The environment '$env' is not initialized."
        info_ "Initialize it with 'py init $env'"
        return 1
    fi
}
