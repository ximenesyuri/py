function list_() {
    if ! inside_; then
        return 1
    fi

    local env=""
    local show_all=true
    local show_installed=false
    local show_not_installed=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--env)
                env="$2"
                shift 2
                ;;
            --installed)
                show_installed=true
                show_all=false
                shift
                ;;
            --not-installed)
                show_not_installed=true
                show_all=false
                shift
                ;;
            -h|--help)
                echo "Usage: py list [options]"
                echo "List project dependencies and their installation status."
                echo ""
                echo "Options:"
                echo "  -e, --env <env>        Specify environment"
                echo "  --installed            Show only installed dependencies"
                echo "  --not-installed        Show only not installed dependencies"
                echo "  -h, --help             Show this help message"
                return 0
                ;;
            *)
                error_ "Unknown option: $1"
                return 1
                ;;
        esac
    done

    local venv_path
    venv_path=$(venv_ "$env")
    
    if [[ ! -d "$venv_path" ]]; then
        error_ "The environment '$(env_ $env)' was not initialized."
        return 1
    fi

    local root
    root=$(find_ root)
    local pyproject="$root/pyproject.toml"

    if [[ ! -f "$pyproject" ]]; then
        error_ "pyproject.toml not found."
        return 1
    fi

    local installed_pkgs
    installed_pkgs=$(get_installed_packages "$venv_path")

    local deps
    deps=$(get_pyproject_dependencies "$pyproject")

    if [[ -z "$deps" ]]; then
        info_ "No dependencies found in pyproject.toml."
        return 0
    fi

    local installed_count=0
    local not_installed_count=0
    local total_count=0

    while IFS= read -r dep_line; do
        [[ -z "$dep_line" ]] && continue
        
        local dep_name
        dep_name=$(echo "$dep_line" | cut -d'|' -f1)
        local dep_spec
        dep_spec=$(echo "$dep_line" | cut -d'|' -f2)
        
        total_count=$((total_count + 1))
        
        if echo "$installed_pkgs" | grep -q "^${dep_name}$"; then
            local status="✓ installed"
            local is_installed=true
            installed_count=$((installed_count + 1))
        else
            local status="✗ not installed"
            local is_installed=false
            not_installed_count=$((not_installed_count + 1))
        fi

        if [[ "$show_all" == true ]] || 
           [[ "$show_installed" == true && "$is_installed" == true ]] || 
           [[ "$show_not_installed" == true && "$is_installed" == false ]]; then
            
            printf "%-30s %s\n" "$dep_name" "$status"
            if [[ -n "$dep_spec" && "$dep_spec" != "$dep_name" ]]; then
                printf "  %s\n" "$dep_spec"
            fi
        fi
    done <<< "$deps"

    echo ""
    echo "Summary: $installed_count installed, $not_installed_count not installed, $total_count total"
}

function get_installed_packages() {
    local venv_path="$1"
    local site_packages="$venv_path/lib/python"*"/site-packages"
    
    for site_pkg_dir in $site_packages; do
        if [[ -d "$site_pkg_dir" ]]; then
            find "$site_pkg_dir" -maxdepth 1 \( -type d -not -name "*.*" -not -name "__pycache__" \) -o \
                 \( -type d -name "*.dist-info" \) 2>/dev/null | \
                 xargs -n 1 basename 2>/dev/null | \
                 sed 's/-[^-]*\.dist-info$//' | \
                 sort -u
            return 0
        fi
    done
}

function get_pyproject_dependencies() {
    local pyproject="$1"
    
    awk '
    BEGIN { in_deps = 0 }
    # Match the start of dependencies section
    /^[[:space:]]*\[project\][[:space:]]*$/ { next }
    /^[[:space:]]*dependencies[[:space:]]*=[[:space:]]*\[/ { 
        in_deps = 1
        next 
    }
    # If we are in deps section and find closing bracket, exit
    in_deps && /\]/ { exit }
    # If we are in deps section, extract dependency names
    in_deps && /^[[:space:]]*".*"[[:space:]]*(,)?$/ {
        line = $0
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        gsub(/^"|"$/, "", line)
        gsub(/,$/, "", line)
        
        if (length(line) > 0) {
            # Extract package name
            pkg_spec = line
            gsub(/[<>=! @].*$/, "", pkg_spec)
            gsub(/^git\+/, "", pkg_spec)
            
            if (length(pkg_spec) > 0) {
                printf "%s|%s\n", pkg_spec, line
            }
        }
    }
    ' "$pyproject"
}

