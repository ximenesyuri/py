function update_() {
    local packages=()
    local env=""
    local path_file=""
    local recursive=false

    declare -a flag_from=() 
    declare -a flag_rec=()
    declare -a flag_path=()
    flag_from+=(${FLAGS[--from]})
    flag_from+=(${FLAGS[--env]})
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
                pip install --upgrade -r "$path_file"
            else
                error_ "The file '$path_file' does not exist or is not a .txt file."
            fi
        else
            local req_file=$(req_ "$env")
            if [[ -f "$req_file" ]]; then
                pip install --upgrade -r "$req_file"
            else
                error_ "Requirements file for environment '$env' not found."
            fi
        fi
    else
        local root
        root=$(find_ root)
        local pyproject="$root/pyproject.toml"
        
        for pkg in "${packages[@]}"; do
            local is_git_dep=false
            local git_spec=""
            
            if [[ -f "$pyproject" ]]; then
                git_spec=$(awk -v pkg="$pkg" '
                BEGIN { in_deps = 0 }
                /^[[:space:]]*dependencies[[:space:]]*=[[:space:]]*\[/ { 
                    in_deps = 1
                    next 
                }
                in_deps && /\]/ { exit }
                in_deps && /^[[:space:]]*".*"[[:space:]]*(,)?$/ {
                    line = $0
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                    gsub(/^"|"$/, "", line)
                    gsub(/,$/, "", line)
                    
                    # Extract package name
                    pkg_name = line
                    gsub(/[<>=! @].*$/, "", pkg_name)
                    gsub(/^git\+/, "", pkg_name)
                    
                    if (pkg_name == pkg) {
                        # Check if this is a git dependency (contains @ or git+)
                        if (line ~ /[ @]/ && line ~ /git\+/) {
                            print line
                            exit
                        }
                    }
                }
                ' "$pyproject")
                
                if [[ -n "$git_spec" ]]; then
                    is_git_dep=true
                fi
            fi
            
            if [[ "$is_git_dep" == true ]]; then
                log_ "Updating git dependency '$pkg'..."
                pip uninstall -y "$pkg" >/dev/null 2>&1
                local clean_git_spec
                clean_git_spec=$(echo "$git_spec" | sed 's/"$//' | sed 's/^"//')
                pip install --no-deps "$clean_git_spec"
                if [[ $? -eq 0 ]]; then
                    done_ "Git dependency '$pkg' has been updated."
                else
                    error_ "Failed to update git dependency '$pkg'."
                fi
            else
                pip install --upgrade "$pkg"
                if [[ $? -eq 0 ]]; then
                    done_ "Package '$pkg' has been updated."
                else
                    error_ "Failed to update package '$pkg'."
                fi
            fi
        done
    fi
    deactivate
}

