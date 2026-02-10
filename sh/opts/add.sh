function add_(){
    if ! inside_; then
        return 1
    fi

    local raw_dep=""
    local provider=""
    local dep_name=""
    local version=""
    local branch=""
    local commit=""
    local protocol="https"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from)
                provider="$2"
                shift 2
                ;;
            --name)
                dep_name="$2"
                shift 2
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            --commit)
                commit="$2"
                shift 2
                ;;
            --protocol)
                protocol="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: py add <dep> [--name <name>] [--version <version>] [--from github|gitlab|bitbucket|pypi] [--branch <branch>] [--commit <commit>] [--protocol https|ssh]"
                return 0
                ;;
            -*)
                error_ "Unknown option '$1' for 'py add'."
                return 1
                ;;
            *)
                if [[ -z "$raw_dep" ]]; then
                    raw_dep="$1"
                else
                    error_ "Multiple dependencies not supported in a single 'py add' call."
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$raw_dep" ]]; then
        error_ "Missing dependency. Usage: py add <dep> [--name ...] [--version ...] [--from ...]"
        return 1
    fi

    if [[ -z "$provider" ]]; then
        if [[ "$raw_dep" == */* && "$raw_dep" != /* && "$raw_dep" != */ ]]; then
            provider="github"
        else
            provider="pypi"
        fi
    fi

    local root
    root=$(find_ root)
    local req_file="$root/requirements.txt"
    local pyproject="$root/pyproject.toml"

    if [[ ! -f "$pyproject" ]]; then
        error_ "pyproject.toml not found. Initialize the project with 'py init' first."
        return 1
    fi

    [[ -f "$req_file" ]] || touch "$req_file"

    local spec_pyproject=""
    local spec_requirements=""

    if [[ "$provider" == "pypi" ]]; then
        if [[ -z "$dep_name" ]]; then
            dep_name="$raw_dep"
        fi

        if [[ -n "$version" ]]; then
            local ver_spec="$version"
            case "$ver_spec" in
                [\<\>\=\!\~]*)
                    ;;
                *)
                    ver_spec="==${ver_spec}"
                    ;;
            esac
            spec_pyproject="${dep_name}${ver_spec}"
        else
            spec_pyproject="${dep_name}"
        fi
        spec_requirements="$spec_pyproject"

    else
        local host="$provider"
        case "$provider" in
            github) host="github.com" ;;
            gitlab) host="gitlab.com" ;;
            bitbucket) host="bitbucket.org" ;;
        esac

        local base_url="$raw_dep"
        if [[ "$base_url" != *"://"* ]]; then
            if [[ "$protocol" == "ssh" ]]; then
                base_url="ssh://git@${host}/${raw_dep}"
            else
                base_url="https://${host}/${raw_dep}"
            fi
        fi

        local url_no_query="${base_url%%\?*}"
        local repo_segment="${url_no_query##*/}"
        local repo_name="${repo_segment%.git}"

        if [[ -z "$dep_name" ]]; then
            dep_name="$repo_name"
        fi

        local git_url="$base_url"
        if [[ "$git_url" != git+* ]]; then
            git_url="git+${git_url}"
        fi

        spec_pyproject="${dep_name} @ ${git_url}"
        spec_requirements="${git_url}"

        if [[ -n "$commit" ]]; then
            spec_pyproject+="@${commit}"
            spec_requirements+="@${commit}"
        elif [[ -n "$branch" ]]; then
            spec_pyproject+="@${branch}"
            spec_requirements+="@${branch}"
        fi
    fi

    if grep -Fxq "$spec_requirements" "$req_file"; then
        warn_ "Entry '$spec_requirements' already present in 'requirements.txt'."
    else
        echo "$spec_requirements" >> "$req_file"
    fi

    if grep -Eq "^[[:space:]]*\"${dep_name}\b" "$pyproject"; then
        warn_ "Dependency '$dep_name' already added."
        return 0
    fi 

    local escaped_spec
    escaped_spec=$(printf '%s\n' "$spec_pyproject" | sed 's/"/\\"/g')

    local tmp="${pyproject}.tmp"

    awk -v spec="$escaped_spec" '
        BEGIN {
            in_deps = 0
            added = 0
        }
        # First dependencies = [ block we see
        $0 ~ /^[[:space:]]*dependencies[[:space:]]*=/ && in_deps == 0 {
            in_deps = 1
            print
            next
        }
        # Closing bracket of that dependencies block
        in_deps == 1 && $0 ~ /\]/ {
            printf "    \"%s\",\n", spec
            added = 1
            in_deps = 0
            print
            next
        }
        { print }
        END {
            # If no dependencies block was found at all, append a new one
            if (added == 0) {
                print ""
                print "dependencies = ["
                printf "    \"%s\",\n", spec
                print "]"
            }
        }
    ' "$pyproject" > "$tmp"

    mv "$tmp" "$pyproject"

    done_ "Added '$dep_name'."
}

