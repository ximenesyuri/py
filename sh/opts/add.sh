function add_(){
    local packages=()
    local registry="pypi"
    local env=""

    if ! inside_; then
        return 1
    fi

    declare -a flag_from=()
    declare -a flag_to=()
    declare -a flag_path=()
    flag_from+=(${FLAGS[--from]})
    flag_from+=(${FLAGS[--registry]})
    flag_to+=(${FLAGS[--to]})
    flag_to+=(${FLAGS[--env]})
    flag_path+=(${FLAGS[--path]})

    while [[ $# -gt 0 ]]; do
        if [[ ! $1 == -* ]]; then
            packages+=($1)
            shift
            continue
        fi
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
    if [[ -n "$path_file" ]]; then
        local req_file="$path_file"
        local req=${req_file##*/}
    else
        local req_file=$(req_ "$env")
        local req=${req_file##*/}
    fi
    for pkg in "${packages[@]}"; do
        if [[ "$registry" == "github" ]]; then
            local owner_repo_branch=(${pkg//[@]/ })
            local owner_repo="${owner_repo_branch[0]}"
            local branch="${owner_repo_branch[1]}"

            if [[ -n "$PY_CONF" ]]; then
                if [[ -z "$branch" ]]; then
                    branch=$(yq eval '.git.github.branch' $PY_CONF)
                    if [[ "$branch" == "null" ]]; then
                        branch="main"
                    fi
                fi
            else
                branch="main"
            fi
            pkg="git+https://github.com/$owner_repo.git@$branch"
        fi        
        if $(match_ "$pkg" "$req_file"); then
            warn_ "pkg '$pkg' already in '$req'."
            continue
        fi
        [[ ! -f "$req_file" ]] && touch "$req_file"
        echo "$pkg" >> "$req_file"
        done_ "pkg '$pkg' added to '$req'."
    done  
}
