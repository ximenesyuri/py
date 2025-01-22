function add_(){
    local packages=()
    local registry="pypi"
    local env=""

    local specified_branch=""
    local specified_commit=""
    local specified_version=""
    
    if ! inside_; then
        return 1
    fi

    declare -a flag_from=()
    declare -a flag_to=()
    declare -a flag_path=()
    declare -a flag_branch=()
    declare -a flag_commit=()
    declare -a flag_version=()
    
    flag_from+=(${FLAGS[--from]})
    flag_from+=(${FLAGS[--registry]})
    flag_to+=(${FLAGS[--to]})
    flag_to+=(${FLAGS[--env]})
    flag_path+=(${FLAGS[--path]})
    flag_branch+=(${FLAGS[--branch]})
    flag_commit+=(${FLAGS[-c]})
    flag_commit+=(${FLAGS[--commit]})
    flag_version+=(${FLAGS[-v]})
    flag_version+=(${FLAGS[--version]})

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
        for flag in "${flag_branch[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                specified_branch="$2"
                shift 2
                continue
            fi
        done
        for flag in "${flag_commit[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                specified_commit="$2"
                shift 2
                continue
            fi
        done
        for flag in "${flag_version[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                specified_version="$2"
                shift 2
                continue
            fi
        done
    done
    
    if ! has_venv_ "$env"; then
        error_ "the environment '$(env_ $env)' was not initialized."
        info_  "initialize it with 'py init'."
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
            IFS=':' read -r owner_repo branch commit <<< "${pkg//:/ }"
            branch="${specified_branch:-$branch}"
            commit="${specified_commit:-$commit}"
            branch="${branch:-main}"

            if is_commit_ "$commit"; then
                pkg="git+https://github.com/$owner_repo.git@$commit#$branch"
            else
                pkg="git+https://github.com/$owner_repo.git@$branch"
            fi
        else
            local version="${pkg##*:}"
            if is_version_ "$version"; then
                pkg="${pkg%%:*}$specified_version"
            elif [[ -n "$specified_version" ]]; then
                if is_version_ "$specified_version"; then
                    pkg="${pkg%%:*}$specified_version"
                else
                    error_ "Invalid specified version format: $specified_version"
                    continue
                fi
            else
                error_ "Invalid package format or missing version: $pkg"
                continue
            fi
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

