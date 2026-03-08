function exec_() {
    if ! inside_; then
        return 1
    fi

    local env=""
    local root
    root=$(find_ root) || {
        error_ "Not inside a Python project."
        return 1
    }

    declare -a flag_env=()
    flag_env+=(${FLAGS[--from]})
    flag_env+=(${FLAGS[--env]})

    local args=()

    while [[ $# -gt 0 ]]; do
        local matched_flag=false
        for flag in "${flag_env[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                if [[ -z "$2" ]]; then
                    error_ "Flag '$1' requires a value."
                    return 1
                fi
                env="$2"
                shift 2
                matched_flag=true
                break
            fi
        done
        $matched_flag && continue

        case "$1" in
            -h|--help)
                echo "Usage: py exec [--env ENV] <command ...>"
                echo "       py exec [--from ENV] <command ...>"
                echo
                echo "Examples:"
                echo "  py exec main.py arg1 arg2"
                echo "  py exec --env dev python -m pytest"
                echo "  py exec --from dev some command with args"
                return 0
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#args[@]} -eq 0 ]]; then
        error_ "Missing command. Usage: py exec [--env ENV] <command ...>"
        return 1
    fi

    local sitedir
    sitedir=$(site_dir_ "$env") || true

    local env_file="${root}/.env${env:+.$env}"
    if [[ -f "$env_file" ]]; then
        set -a
        source <(cat "$env_file" | xargs -n1)
        set +a
    fi

    local pp="$root"
    [[ -n "$sitedir" && -d "$sitedir" ]] && pp="$sitedir:$pp"
    [[ -n "$PYTHONPATH" ]] && pp="$pp:$PYTHONPATH"

    if [[ -f "${args[0]}" ]]; then
        PYTHONPATH="$pp" python3 "${args[@]}"
        return $?
    fi
    printf -v cmd_str '%q ' "${args[@]}"

    PYTHONPATH="$pp" eval "$cmd_str"
}

