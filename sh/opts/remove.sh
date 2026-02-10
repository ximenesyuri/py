function remove_(){
    if ! inside_; then
        return 1
    fi

    if [[ $# -lt 1 ]]; then
        error_ "Usage: py remove <name> [<name> ...]"
        return 1
    fi

    local root
    root=$(find_ root)
    local req_file="$root/requirements.txt"
    local pyproject="$root/pyproject.toml"

    if [[ ! -f "$pyproject" ]]; then
        error_ "pyproject.toml not found."
        return 1
    fi

    local name
    for name in "$@"; do
        local escaped_name
        escaped_name=$(printf '%s\n' "$name" | sed 's/[.[\*^$\/&]/\\&/g')

        if [[ -f "$req_file" ]]; then
            sed -i "/^${escaped_name}\([<=> ].*\)\?$/d" "$req_file"
            sed -i "/#egg=${escaped_name}\b/d" "$req_file"
            sed -i "/\/${escaped_name}\.git\b/d" "$req_file"
        fi
        if [[ "$name" == */* ]]; then
            if grep -q "$name" "$pyproject"; then
                local esc_repo
                esc_repo=$(printf '%s\n' "$name" | sed 's/[.[\*^$\/&]/\\&/g')
                sed -i "/\"[^\"]*${esc_repo}[^\"]*\"/d" "$pyproject"
                done_ "Removed '$name'."
            else
                warn_ "Dependency '$name' not found in pyproject.toml."
            fi
        else
            if grep -Eq "^[[:space:]]*\"${name}\b" "$pyproject"; then
                sed -i "/^[[:space:]]*\"${escaped_name}\b/d" "$pyproject"
                done_ "Removed '$name'."
            else
                warn_ "Dependency '$name' not found in pyproject.toml."
            fi
        fi
    done 
}

