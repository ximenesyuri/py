function add(){
    local packages=()
    local registry="pypi"
    local env=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--from) registry="$2"; shift 2;;
            -t|--to) env="$2"; shift 2;;
            *) packages+=("$1"); shift;;
        esac
    done

    local req_file="requirements${env:+.${env}}.txt"
    
    for pkg in "${packages[@]}"; do
        if [[ "$registry" == "github" ]]; then
            local owner_repo_branch=(${pkg//[@]/ })
            local owner_repo="${owner_repo_branch[0]}"
            local branch="${owner_repo_branch[1]}"

            if [[ -n "$PY_YML_GLOBAL" ]]; then
                if [[ -z "$branch" ]]; then
                    branch=$(yq eval '.git.github.branch' py.yml)
                    if [[ "$branch" == "null" ]]; then
                        branch="main"
                    fi
                fi
            else
                branch="main"
            fi

            pkg="git+https://github.com/$owner_repo.git@$branch"
        fi
        

        if $(has_ "$pkg" "$req_file"); then
            echo "error: The package '$pkg' was already included in '$req_file'."
            return 1
        fi
        [ ! -f "$req_file" ] && touch "$req_file"
        echo "$pkg" >> "$req_file"
    done  
}
