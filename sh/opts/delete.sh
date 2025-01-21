function delete_(){
    local entries=()
    local env=""
    local path_file=""
    local req_file=""

    if ! inside_; then
        return 1
    fi
    
    declare -a flag_from=()
    declare -a flag_path=()
    flag_from+=(${FLAGS[--from]})
    flag_from+=(${FLAGS[--env]})
    flag_path+=(${FLAGS[--path]})

    while [[ $# -gt 0 ]]; do
        if [[ ! $1 == -* ]]; then
            entries+=("$1")
            shift
            continue
        fi
        for flag in "${flag_from[@]}"; do
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

    if [[ -n "$path_file" ]]; then
        if [[ -f "$path_file" && "$path_file" == *.txt ]]; then
            req_file="$path_file"
        else
            error_ "The file '$path_file' does not exist or is not a .txt file."
            return 1
        fi
    else
        req_file=$(req_ "$env")
    fi

    if [[ ! -f "$req_file" ]]; then
        error_ "The file '$req_file' does not exist."
        return 1
    fi
    if [[ ${#entries[@]} -eq 0 ]]; then
        if [[ -s "$req_file" ]]; then
            local selected_entries
            selected_entries=$(cat "$req_file" | fzf --multi | sed 's/[]\/$*.^|[]/\\&/g')

            if [[ -n "$selected_entries" ]]; then
                while IFS= read -r entry; do
                    sed -i "/^${entry}$/d" "$req_file"
                done <<< "$selected_entries"
                done_ "Selected entries were deleted from '$req_file'."
            else
                info_ "No entries were selected for deletion."
            fi
        else
            info_ "The file '$req_file' is empty."
        fi
    else
        for entry in "${entries[@]}"; do
            if match_ "$entry" "$req_file"; then
                sed -i "/^${entry}$/d" "$req_file"
                if [[ $? -eq 0 ]]; then
                    done_ "'$entry' has been deleted."
                else
                    warn_ "'$entry' could not be delete."
                fi
            else
                error_ "'$entry' not found in '$req_file'."
            fi
        done
    fi
    return 0
}

