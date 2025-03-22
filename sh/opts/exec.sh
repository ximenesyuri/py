function exec_() {
    local target="$@"
    local env=""
    shift

    declare -a flag_from=()
    flag_from+=(${FLAGS[--from]})
    flag_from+=(${FLAGS[--env]})

    while [[ $# -gt 0 ]]; do
        for flag in "${flag_from[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                env="$2"
                shift 2
                continue 2
            fi
        done
        shift
    done

    local venv_path=$(venv_ "$env")
    if [[ ! -d "$venv_path" ]]; then
        error_ "The environment '$(env_ $env)' was not initialized."
        return 1
    fi

    local root=$(find_ root)
    local env_file="${root}/.env${env:+.$env}"
    if [[ -f "$env_file" ]]; then
        set -a
        source <(cat "$env_file" | xargs -n1)
        set +a
    fi

    activate_ "$env"

    if [[ -f "$target" ]]; then
        python3 "$target"
    else
        eval "$target"
    fi

    deactivate
}
