function uninstall_() {
    if ! inside_; then
        return 1
    fi

    local packages=()
    local env=""
    local path_file=""
    local recursive=false

    declare -a flag_from=()
    declare -a flag_to=()
    declare -a flag_rec=()
    declare -a flag_path=()
    flag_from+=(${FLAGS[--from]})
    flag_from+=(${FLAGS[--registry]})
    flag_to+=(${FLAGS[--to]})
    flag_to+=(${FLAGS[--env]})
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
                # registry is ignored for uninstall in target model, but parse to keep interface
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
        shift
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

    # Helper to remove one package from target site-packages
    _py_remove_pkg_from_site() {
        local name="$1"
        local dir="$2"

        local removed=false

        # main package dir
        if [[ -d "$dir/$name" ]]; then
            rm -rf "$dir/$name"
            removed=true
        fi

        # dist-info dirs
        local di
        for di in "$dir"/"$name"-*.dist-info; do
            [[ -e "$di" ]] || continue
            rm -rf "$di"
            removed=true
        done

        if $removed; then
            done_ "Removed package '$name' from '$dir'."
        else
            warn_ "Package '$name' not found in '$dir'."
        fi
    }

    if $recursive; then
        local file
        if [[ -n "$path_file" ]]; then
            file="$path_file"
        else
            file=$(req_ "$env")
        fi
        if [[ -f "$file" ]]; then
            while IFS= read -r pkg; do
                pkg="${pkg%%#*}"     # strip comments
                pkg="${pkg%%[[:space:]]*}" # trim trailing
                [[ -z "$pkg" ]] && continue
                _py_remove_pkg_from_site "$pkg" "$sitedir"
            done < "$file"
        else
            error_ "The file '$file' does not exist."
            return 1
        fi
    else
        for pkg in "${packages[@]}"; do
            _py_remove_pkg_from_site "$pkg" "$sitedir"
        done
    fi
}

