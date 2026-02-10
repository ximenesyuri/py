function version_() {
    function get_current_version() {
        local pyproject="$1"
        awk -F' = ' '
        /^[[:space:]]*version[[:space:]]*=/ {
            ver = $2
            gsub(/^[ "]*/, "", ver)
            gsub(/[ "]*/, "", ver)
            gsub(/,$/, "", ver)
            print ver
            exit
        }
        ' "$pyproject"
    }

    function update_version() {
        local version="$1"
        local type="$2"
        local back="$3"

        local major minor patch
        IFS='.' read -r major minor patch <<< "$version"
        
        major=${major:-0}
        minor=${minor:-0}
        patch=${patch:-0}

        if ! [[ "$major" =~ ^[0-9]+$ ]] || ! [[ "$minor" =~ ^[0-9]+$ ]] || ! [[ "$patch" =~ ^[0-9]+$ ]]; then
            error_ "Invalid version format: $version"
            return 1
        fi

        if [[ "$back" == true ]]; then
            case "$type" in
                major)
                    if [[ $major -gt 0 ]]; then
                        major=$((major - 1))
                    else
                        major=0
                    fi
                    minor=0
                    patch=0
                    ;;
                minor)
                    if [[ $minor -gt 0 ]]; then
                        minor=$((minor - 1))
                    else
                        minor=0
                    fi
                    patch=0
                    ;;
                patch)
                    if [[ $patch -gt 0 ]]; then
                        patch=$((patch - 1))
                    else
                        patch=0
                    fi
                    ;;
                *)
                    error_ "Invalid version type: $type"
                    return 1
                    ;;
            esac
        else
            case "$type" in
                major)
                    major=$((major + 1))
                    minor=0
                    patch=0
                    ;;
                minor)
                    minor=$((minor + 1))
                    patch=0
                    ;;
                patch)
                    patch=$((patch + 1))
                    ;;
                *)
                    error_ "Invalid version type: $type"
                    return 1
                    ;;
            esac
        fi

        echo "${major}.${minor}.${patch}"
    }

    function update_pyproject_version() {
        local pyproject="$1"
        local new_version="$2"
        local temp_file="${pyproject}.tmp"

        awk -v new_version="$new_version" '
        /^[[:space:]]*version[[:space:]]*=/ {
            # Replace the version line
            if ($0 ~ /=.*,[[:space:]]*$/) {
                # Keep trailing comma if it exists
                print "version = \"" new_version "\","
            } else {
                print "version = \"" new_version "\""
            }
            next
        }
        { print }
        ' "$pyproject" > "$temp_file"

        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$pyproject"
            return 0
        else
            rm -f "$temp_file" 2>/dev/null
            return 1
        fi
    }
    if ! inside_; then
        return 1
    fi

    local root
    root=$(find_ root)
    local pyproject="$root/pyproject.toml"
    local back=false
    local version_type=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --back)
                back=true
                shift
                ;;
            patch|minor|major)
                version_type="$1"
                shift
                ;;
            -h|--help)
                echo "Usage: py version [patch|minor|major] [--back]"
                echo "Update the project version in pyproject.toml"
                echo ""
                echo "Commands:"
                echo "  patch     Increment/decrement patch version (0.0.1 -> 0.0.2)"
                echo "  minor     Increment/decrement minor version (0.1.0 -> 0.2.0)"
                echo "  major     Increment/decrement major version (1.0.0 -> 2.0.0)"
                echo ""
                echo "Options:"
                echo "  --back    Decrement version instead of incrementing"
                echo "  -h, --help Show this help message"
                return 0
                ;;
            *)
                if [[ -z "$version_type" ]]; then
                    version_type="$1"
                else
                    error_ "Unknown option: $1"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$version_type" ]]; then
        error_ "Version type required. Use: patch, minor, or major"
        return 1
    fi

    if [[ ! -f "$pyproject" ]]; then
        error_ "pyproject.toml not found."
        return 1
    fi

    local current_version
    current_version=$(get_current_version "$pyproject")
    
    if [[ -z "$current_version" ]]; then
        error_ "Could not find version in pyproject.toml"
        return 1
    fi

    local new_version
    new_version=$(update_version "$current_version" "$version_type" "$back")
    
    if [[ $? -ne 0 ]]; then
        error_ "Failed to update version"
        return 1
    fi

    update_pyproject_version "$pyproject" "$new_version"
    
    if [[ $? -eq 0 ]]; then
        done_ "Version updated from $current_version to $new_version"
    else
        error_ "Failed to update version in pyproject.toml"
        return 1
    fi
}
