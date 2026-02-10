function build_() {
    if ! inside_; then
        return 1
    fi

    local root
    root=$(find_ root)
    local pyproject="$root/pyproject.toml"
    local env=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--env)
                env="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: py build [options]"
                echo "Build the current Python package"
                echo ""
                echo "Options:"
                echo "  -e, --env <env>        Specify environment"
                echo "  -h, --help             Show this help message"
                return 0
                ;;
            *)
                error_ "Unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ ! -f "$pyproject" ]]; then
        error_ "pyproject.toml not found."
        return 1
    fi

    if [[ -n "$env" ]]; then
        if ! has_venv_ "$env"; then
            error_ "The environment '$(env_ $env)' was not initialized."
            return 1
        fi
        activate_ "$env"
    else
        if ! has_venv_; then
            error_ "No environment initialized."
            return 1
        fi
        activate_
    fi

    log_ "Cleaning previous builds..."
    rm -rf "$root/build" "$root/dist" "$root"/*.egg-info 2>/dev/null
    mkdir -p "$root/dist"

    local name version description
    name=$(awk -F' = ' '/^[[:space:]]*name[[:space:]]*=/ {
        gsub(/^[ "]*/, "", $2); gsub(/[ ",]*/, "", $2); print $2; exit
    }' "$pyproject")
    version=$(awk -F' = ' '/^[[:space:]]*version[[:space:]]*=/ {
        gsub(/^[ "]*/, "", $2); gsub(/[ ",]*/, "", $2); gsub(/,$/, "", $2); print $2; exit
    }' "$pyproject")
    description=$(awk -F' = ' '/^[[:space:]]*description[[:space:]]*=/ {
        gsub(/^[ "]*/, "", $2); gsub(/[ ",]*/, "", $2); gsub(/,$/, "", $2); print $2; exit
    }' "$pyproject")

    name=${name:-$(basename "$root")}
    version=${version:-"0.1.0"}
    description=${description:-""}

    local include_str
    include_str=$(awk '
        /^\[tool\.setuptools\.packages\.find\]/ { in_find=1; next }
        /^\[/ && in_find { exit }  # next table -> stop
        in_find && /^[[:space:]]*include[[:space:]]*=/ {
            line = $0
            # strip up to first [
            sub(/^[^[]*\[/, "", line)
            # strip from closing ] to end
            sub(/\].*$/, "", line)
            gsub(/"/, "", line)
            gsub(/[[:space:]]*,[[:space:]]*/, " ", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            print line
            exit
        }
    ' "$pyproject")

    local patterns=()
    if [[ -n "$include_str" ]]; then
        patterns=($include_str)
    fi

    if [[ ${#patterns[@]} -eq 0 ]]; then
        warn_ "No [tool.setuptools.packages.find.include] patterns found; no packages will be copied."
        warn_ "Update pyproject.toml or extend build_ if you need a fallback."
    fi

    log_ "Creating source distribution..."
    local temp_dir="$root/dist/${name}-${version}"
    mkdir -p "$temp_dir"

    cp "$pyproject" "$temp_dir/"

    local meta
    for meta in README* LICENSE*; do
        if [[ -f "$root/$meta" ]]; then
            cp "$root/$meta" "$temp_dir/"
        fi
    done

    local entry base pat matched
    for entry in "$root"/*; do
        [[ -d "$entry" ]] || continue
        base=$(basename "$entry")

        case "$base" in
            dist|build|.venv*|.git|__pycache__|*.egg-info)
                continue
                ;;
        esac

        matched=false
        for pat in "${patterns[@]}"; do
            if [[ "$base" == $pat ]]; then
                matched=true
                break
            fi
        done

        $matched || continue

        if [[ -f "$entry/__init__.py" ]]; then
            cp -r "$entry" "$temp_dir/"
        else
            warn_ "Directory '$base' matches include pattern but has no __init__.py; skipping."
        fi
    done

    cat > "$temp_dir/PKG-INFO" <<EOF
Metadata-Version: 2.1
Name: ${name}
Version: ${version}
Summary: ${description}
EOF

    cd "$root/dist"
    tar -czf "${name}-${version}.tar.gz" "${name}-${version}" >/dev/null 2>&1

    if [[ $? -eq 0 && -f "${name}-${version}.tar.gz" ]]; then
        rm -rf "$temp_dir"
        cd "$root"
        done_ "Source distribution built successfully: ${name}-${version}.tar.gz"
    else
        error_ "Failed to create source distribution."
        rm -rf "$temp_dir" 2>/dev/null
        cd "$root"
        deactivate
        return 1
    fi

    deactivate
}

