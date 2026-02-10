function dot_() {
    if ! inside_; then
        return 1
    fi

    if [[ $# -lt 1 ]]; then
        error_ "Usage: py . <dependency_name>"
        return 1
    fi

    local dep_name="$1"
    local env=""
    
    if [[ "$2" == "-e" || "$2" == "--env" ]]; then
        env="$3"
    fi

    local venv_path
    venv_path=$(venv_ "$env")
    
    if [[ ! -d "$venv_path" ]]; then
        error_ "The environment '$(env_ $env)' was not initialized."
        return 1
    fi

    local site_packages="$venv_path/lib/python"*"/site-packages"
    local dep_path=""
    
    for site_pkg_dir in $site_packages; do
        if [[ -d "$site_pkg_dir" ]]; then
            if [[ -d "$site_pkg_dir/$dep_name" ]]; then
                dep_path="$site_pkg_dir/$dep_name"
                break
            fi
            if [[ -f "$site_pkg_dir/$dep_name.egg-link" ]]; then
                dep_path=$(head -n 1 "$site_pkg_dir/$dep_name.egg-link")
                break
            fi
            if [[ -d "$site_pkg_dir/$dep_name-"*".dist-info" ]]; then
                if [[ -d "$site_pkg_dir/$dep_name" ]]; then
                    dep_path="$site_pkg_dir/$dep_name"
                else
                    local top_level_file="$site_pkg_dir/$dep_name-"*".dist-info/top_level.txt"
                    if [[ -f $top_level_file ]]; then
                        local top_level_pkg
                        top_level_pkg=$(head -n 1 "$top_level_file")
                        if [[ -n "$top_level_pkg" && -d "$site_pkg_dir/$top_level_pkg" ]]; then
                            dep_path="$site_pkg_dir/$top_level_pkg"
                        fi
                    fi
                fi
                break
            fi
        fi
    done

    if [[ -z "$dep_path" || ! -d "$dep_path" ]]; then
        error_ "Dependency '$dep_name' not found in virtual environment."
        info_ "Make sure the package is installed in environment '$(env_ $env)'."
        return 1
    fi

    log_ "Entering dependency directory: $dep_path"
    cd "$dep_path"
    
    ${SHELL:-bash}
    
    log_ "Exited dependency directory."
}

