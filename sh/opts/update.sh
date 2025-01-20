function update_() {
    local packages=()
    local env=""
    local update_all=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            "${FLAGS[--recursive]}")
                update_all=true
                shift
                if [[ $# -gt 0 ]]; then
                    local arg="$1"
                    if is_path_ "$arg" && is_txt_ "$arg"; then
                        local req_file="$arg"
                        shift
                    elif has_env_ "$arg"; then
                        env="$arg"
                        shift
                    else
                        error_ "Argument '$arg' is neither a valid environment nor a .txt file."
                        return 1
                    fi
                fi
                ;;
            "${FLAGS[--to]}"|${FLAGS[--env]})
                env="$2"
                shift 2
                ;;
            *)
                packages+=("$1")
                shift
                ;;
        esac
    done
 
    if [[ -n "$env" ]] && ! has_env_ "$env"; then
        error_ "The environment '$env' is not initialized."
        info_  "Try 'py init $env'."
        return 1
    elif [[ -z "$env" ]] && ! [[ -d ".venv" ]]; then
        error_ "The main environment is not initialized."
        info_  "Try 'py init'."
        return 1
    fi

    [[ -z "$env" ]] && venv=".venv"

    activate_ $env
    if $update_all; then
        if [[ -n "$req_file" ]]; then
            pip install -r "$req_file"
        else
            outdated_packages=$(pip list --outdated --format=freeze | cut -d '=' -f 1)
            if [ -z "$outdated_packages" ]; then
                log_ "Environment '$env' is up-to-date."
            else
                log_ "Updating packages in environment '$env':"
                echo "$outdated_packages" | xargs -n1 pip install -U
            fi
        fi
    else
        for pkg in "${packages[@]}"; do
            pip install --upgrade "$pkg"
        done
    fi
    deactivate
}
