function install_() {

    if ! inside_; then
        return 1
    fi
    local packages=()
    local registry="pypi"
    local env=""
    local path_file=""
    local recursive=false

    local specified_branch=""
    local specified_commit=""
    local specified_version=""

    declare -a flag_from=()
    declare -a flag_to=()
    declare -a flag_rec=()
    declare -a flag_path=()
    declare -a flag_branch=()
    declare -a flag_commit=()
    declare -a flag_version=()
    
    flag_from+=(${FLAGS[--from]})
    flag_from+=(${FLAGS[--registry]})
    flag_to+=(${FLAGS[--to]})
    flag_to+=(${FLAGS[--env]})
    flag_rec+=(${FLAGS[--recursive]})
    flag_path+=(${FLAGS[--path]})
    flag_branch+=(${FLAGS[--branch]})
    flag_commit+=(${FLAGS[--commit]})
    flag_version+=(${FLAGS[--version]})
    
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
        error_ "The environment '$(env_ $env)' was not initialized."
        return 1
    fi

    activate_ "$env"

    if [[ "$1" == "." ]]; then
        root=$(find_ root)
        log_ "Installing the project in editable mode in env '$(env_ $env)'..."
        cd $root
        pip install -e . > /dev/null 2>&1
        if [[ ! "$?" == "0" ]]; then
            cd - > /dev/null 2>&1
            deactivate
            error_ "Could not install the project in editable mode."
            return 1
        fi
        cd - > /dev/null 2>&1
        deactivate
        return 0
    fi

    if $recursive; then
        if [[ -n "$path_file" ]]; then
            if [[ -f "$path_file" && "$path_file" == *.txt ]]; then
                pip install -r "$path_file"
            else
                error_ "The file '$path_file' does not exist or is not a .txt file."
            fi
        else
            local req_file=$(req_ "$env")
            if [[ -f "$req_file" ]]; then
                pip install -r "$req_file"
            else
                error_ "Requirements file for environment '$env' not found."
            fi
        fi
    else
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
                fi
            fi

            pip install "$pkg"
            if [[ $? -eq 0 ]]; then
                done_ "Package '$pkg' has been installed."
            else
                error_ "Failed to install package '$pkg'."
            fi
        done
    fi
    deactivate
}
