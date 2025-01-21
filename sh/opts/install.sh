function install_() {
    local packages=()
    local registry="pypi"
    local env=""
    local path_file=""
    local recursive=false

    declare -a flag_from=()
    declare -a flag_to=()
    declare -a flag_rec=()
    declare -a flag_path=()
    flag_from+=(${FLAGS[--from]})
    flag_from+=(${FLAGS[--registry]})
    flag_to+=(${FLAGS[--to]})
    flag_to+=(${FLAGS[--env]})
    flag_rec+=(${FLAGS[--recursive]})
    flag_path+=(${FLAGS[--path]})
    
    while [[ $# -gt 0 ]]; do
        if [[ ! $1 == -* ]]; then
            packages+=("$1")
            shift
            continue
        fi
        for flag in "${flag_rec[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                recursive="true"
                shift
                continue
            fi
        done
        for flag in "${flag_from[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                registry="$2"
                shift 2
                continue
            fi
        done
        for flag in "${flag_to[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                env="$2"
                shift 2
                continue
            fi
        done
        for flag in "${flag_path[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                path_file="$2"
                shift 2
                continue
            fi
        done 
    done

    if ! has_venv_ "$env"; then
        error_ "The environment '$(env_ $env)' was not initialized."
        return 1
    fi

    activate_ "$env"
    if $recursive; then
        if [[ -n "$path_file" ]]; then
            if [[ -f "$path_file" && "$path_file" == *.txt ]]; then
                pip install -r "$path_file"
            else
                error_ "The file '$path_file' does not exist or is not a .txt file."
            fi
        else
            local req_file=$(req_ "$env")
            if [[ -f "$req_file" ]]; then
                pip install -r "$req_file"
            else
                error_ "Requirements file for environment '$env' not found."
            fi
        fi
    else
        for pkg in "${packages[@]}"; do
            pip install "$pkg"
            if [[ $? -eq 0 ]]; then
                done_ "Package '$pkg' has been installed."
            else
                error_ "Failed to install package '$pkg'."
            fi
        done
    fi
    deactivate
}
