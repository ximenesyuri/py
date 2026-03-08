function update_() {
    if ! inside_; then
        return 1
    fi

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

    local sitedir
    sitedir=$(site_dir_ "$env") || {
        error_ "Unable to determine site-packages directory for environment '$(env_ $env)'."
        return 1
    }

    if [[ ! -d "$sitedir" ]]; then
        error_ "No site-packages directory found for environment '$(env_ $env)'."
        return 1
    fi
    
    if $recursive; then
        local req_file
        if [[ -n "$path_file" ]]; then
            if [[ -f "$path_file" && "$path_file" == *.txt ]]; then
                req_file="$path_file"
            else
                error_ "The file '$path_file' does not exist or is not a .txt file."
                return 1
            fi
        else
            req_file=$(req_ "$env")
            if [[ ! -f "$req_file" ]]; then
                error_ "Requirements file for environment '$env' not found."
                return 1
            fi
        fi
        python3 -m pip install --target "$sitedir" --upgrade -r "$req_file"
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
                        # Check if this is a git dependency (contains git+)
                        if (line ~ /git\+/) {
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
                local clean_git_spec
                clean_git_spec=$(echo "$git_spec" | sed 's/^"//; s/"$//')
                python3 -m pip install --target "$sitedir" --no-deps --force-reinstall "$clean_git_spec"
                if [[ $? -eq 0 ]]; then
                    done_ "Git dependency '$pkg' has been updated in '$sitedir'."
                else
                    error_ "Failed to update git dependency '$pkg'."
                fi
            else
                python3 -m pip install --target "$sitedir" --upgrade "$pkg"
                if [[ $? -eq 0 ]]; then
                    done_ "Package '$pkg' has been updated in '$sitedir'."
                else
                    error_ "Failed to update package '$pkg'."
                fi
            fi
        done
    fi
}

