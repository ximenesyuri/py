function install_() {

    if ! inside_; then
        return 1
    fi
    local packages=()
    local registry=""
    local env="" 
    local path_file=""
    local recursive=false
    local no_deps=false
    local protocol="https"

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
    declare -a flag_protocol=()
    declare -a flag_no_deps=()
    
    flag_from+=(${FLAGS[--from]})
    flag_from+=(${FLAGS[--registry]})
    flag_to+=(${FLAGS[--to]})
    flag_to+=(${FLAGS[--env]})
    flag_rec+=(${FLAGS[--recursive]})
    flag_path+=(${FLAGS[--path]})
    flag_branch+=(${FLAGS[--branch]})
    flag_commit+=(${FLAGS[--commit]})
    flag_version+=(${FLAGS[--version]})
    flag_protocol+=(${FLAGS[--protocol]})
    flag_no_deps+=(${FLAGS[--no-deps]})
     
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
        for flag in "${flag_protocol[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                protocol="$2"
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
        for flag in "${flag_no_deps[@]}"; do
            if [[ "$1" == "$flag" ]]; then
                no_deps=true
                shift
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

    # Editable install of current project ('.') is no longer needed:
    # init_ already symlinks the project into site-packages.
    if [[ ${#packages[@]} -eq 1 && "${packages[0]}" == "." ]]; then
        info_ "Project is already linked into site-packages by 'py init'; nothing to install."
        return 0
    fi

    # Interactive selection if no packages were given and not recursive
    if ! $recursive && [[ -z "$path_file" ]] && [[ ${#packages[@]} -eq 0 ]]; then
        if ! command -v fzf >/dev/null 2>&1; then
            error_ "'fzf' is required for interactive selection. Please install fzf."
            return 1
        fi

        local did_select=false

        # Prefer querying PyPI if no registry or pypi
        if [[ -z "$registry" || "$registry" == "pypi" ]]; then
            if command -v curl >/dev/null 2>&1; then
                local cache_dir cache_file tmp
                cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/py"
                mkdir -p "$cache_dir"
                cache_file="$cache_dir/pypi_index.txt"

                local refresh=false
                if [[ ! -s "$cache_file" ]]; then
                    refresh=true
                elif [[ -n "$(find "$cache_file" -mtime +7 -print -quit 2>/dev/null)" ]]; then
                    refresh=true
                fi

                if $refresh; then
                    info_ "Fetching package index from PyPI (this may take a few seconds)..."
                    tmp="$cache_file.tmp"
                    if curl -fsSL https://pypi.org/simple/ \
                        | sed -n 's|.*<a href="/simple/\([^"/]*\)/".*>\([^<]*\)</a>.*|\2|p' \
                        | tr '[:upper:]' '[:lower:]' \
                        | sort -u > "$tmp"; then
                        mv "$tmp" "$cache_file"
                    else
                        rm -f "$tmp" >/dev/null 2>&1
                    fi
                fi

                if [[ -s "$cache_file" ]]; then
                    local selected
                    selected=$(fzf --multi --prompt "PyPI packages> " < "$cache_file")
                    if [[ -n "$selected" ]]; then
                        mapfile -t packages <<< "$selected"
                        did_select=true
                    else
                        info_ "No packages selected."
                        return 0
                    fi
                fi
            else
                warn_ "curl not found; falling back to local candidates."
            fi
        fi

        # Fallback to local pip directory or manual input if PyPI fetch didn't run or failed
        if ! $did_select; then
            local root pip_dir candidates
            root=$(find_ root)
            if [[ -n "$PY_PIP_DIR" && -d "$PY_PIP_DIR" ]]; then
                pip_dir="$PY_PIP_DIR"
            elif [[ -d "$root/pip" ]]; then
                pip_dir="$root/pip"
            elif [[ -d "$root/.pip" ]]; then
                pip_dir="$root/.pip"
            elif [[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/pip" ]]; then
                pip_dir="${XDG_CACHE_HOME:-$HOME/.cache}/pip"
            fi

            if [[ -d "$pip_dir" ]]; then
                if compgen -G "$pip_dir/*.txt" > /dev/null; then
                    candidates=$(grep -hE '^[A-Za-z0-9_.-]+' "$pip_dir"/*.txt 2>/dev/null | sed 's/[[:space:]]#.*$//' | sed '/^\s*$/d' | sort -u)
                elif [[ -d "$pip_dir/wheels" ]]; then
                    candidates=$(find "$pip_dir/wheels" -type f -name "*.whl" -printf "%f\n" 2>/dev/null | sed 's/-[0-9].*$//' | tr '_' '-' | sort -u)
                fi
            fi

            if [[ -z "$candidates" ]]; then
                info_ "No candidates found locally. Type packages (space-separated), or leave empty to cancel."
                read -r -p "> " typed_pkgs
                if [[ -z "$typed_pkgs" ]]; then
                    info_ "No packages selected."
                    return 0
                fi
                read -r -a packages <<< "$typed_pkgs"
            else
                local selected
                selected=$(printf "%s\n" "$candidates" | fzf --multi)
                if [[ -z "$selected" ]]; then
                    info_ "No packages selected."
                    return 0
                fi
                mapfile -t packages <<< "$selected"
            fi
        fi
    fi

    if $recursive; then
        if [[ -n "$path_file" ]]; then
            if [[ -f "$path_file" && "$path_file" == *.txt ]]; then
                local pip_args=()
                $no_deps && pip_args+=(--no-deps)
                python3 -m pip install --target "$sitedir" "${pip_args[@]}" -r "$path_file"
            else
                error_ "The file '$path_file' does not exist or is not a .txt file."
            fi
        else
            local req_file
            req_file=$(req_ "$env")
            if [[ -f "$req_file" ]]; then
                local pip_args=()
                $no_deps && pip_args+=(--no-deps)
                python3 -m pip install --target "$sitedir" "${pip_args[@]}" -r "$req_file"
            else
                error_ "Requirements file for environment '$env' not found."
            fi
        fi
    else
        for pkg in "${packages[@]}"; do
            local slashes
            slashes=$(grep -o '/' <<< "$pkg" | wc -l)
            if [[ "$slashes" -eq 1 ]] && 
               [[ "$pkg" != "/"* ]] && 
               [[ "$pkg" != *"/" ]]; then
                # owner/repo style -> git URL handling
                pkg_info_ "$pkg"
                local repo="$repo"
                local branch="$branch"
                local commit="$commit"

                if [[ "$registry" == "github" ]]; then
                    local base=""
                    if [[ "$protocol" == "ssh" ]]; then
                        base="git+ssh://git@github.com/${repo}.git"
                    else
                        base="git+https://github.com/${repo}.git"
                    fi
                    if is_commit_ "$commit"; then
                        pkg="${base}@${commit}#${branch}"
                    else
                        pkg="${base}@${branch}"
                    fi
                elif [[ -z "$registry" ]]; then
                    # Default to GitHub over HTTPS if user gave owner/repo without --from
                    if is_commit_ "$commit"; then
                        pkg="git+https://github.com/$repo.git@$commit#$branch"
                    else
                        pkg="git+https://github.com/$repo.git@$branch"
                    fi
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
            local pip_args=()
            $no_deps && pip_args+=(--no-deps)
            python3 -m pip install --target "$sitedir" "${pip_args[@]}" "$pkg"
            if [[ $? -eq 0 ]]; then
                done_ "Package '$pkg' has been installed into '$sitedir'."
            else
                error_ "Failed to install package '$pkg'."
            fi
        done
    fi
}

