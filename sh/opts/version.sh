function version_() {
    if ! inside_; then
        return 1
    fi

    local root
    root=$(find_ root)
    local pyproject="$root/pyproject.toml"

    if [[ ! -f "$pyproject" ]]; then
        error_ "pyproject.toml not found."
        return 1
    fi

    get_current_version() {
        local file="$1"
        awk -F' = ' '
        /^[[:space:]]*version[[:space:]]*=/ {
            ver = $2
            gsub(/^[ "]*/, "", ver)
            gsub(/[ "]*/, "", ver)
            gsub(/,$/, "", ver)
            print ver
            exit
        }
        ' "$file"
    }

    is_plain_version() {
        [[ "$1" =~ ^[0-9]+(\.[0-9]+){2,3}$ ]]
    }

    bump_version() {
        local version="$1"
        local kind="$2"
        local dir="$3"

        local major=0 minor=0 patch=0 extra=0
        IFS='.' read -r major minor patch extra <<< "$version"

        major=${major:-0}
        minor=${minor:-0}
        patch=${patch:-0}

        if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]]; then
            error_ "Invalid version format: $version"
            return 1
        fi

        if [[ "$dir" == "up" ]]; then
            case "$kind" in
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
                    error_ "Invalid version kind: $kind (use patch, minor, or major)"
                    return 1
                    ;;
            esac
        elif [[ "$dir" == "down" ]]; then
            case "$kind" in
                major)
                    (( major > 0 )) && major=$((major - 1))
                    minor=0
                    patch=0
                    ;;
                minor)
                    (( minor > 0 )) && minor=$((minor - 1))
                    patch=0
                    ;;
                patch)
                    (( patch > 0 )) && patch=$((patch - 1))
                    ;;
                *)
                    error_ "Invalid version kind: $kind (use patch, minor, or major)"
                    return 1
                    ;;
            esac
        else
            error_ "Invalid direction: $dir (use up or down)"
            return 1
        fi

        echo "${major}.${minor}.${patch}"
    }

    update_pyproject_version() {
        local file="$1"
        local new_version="$2"
        local temp_file="${file}.tmp"

        awk -v new_version="$new_version" '
        /^[[:space:]]*version[[:space:]]*=/ {
            # Replace the version line, keep trailing comma if present
            if ($0 ~ /=.*,[[:space:]]*$/) {
                print "version = \"" new_version "\","
            } else {
                print "version = \"" new_version "\""
            }
            next
        }
        { print }
        ' "$file" > "$temp_file" || return 1

        mv "$temp_file" "$file"
    }

    set_version_from_git() {
        local root="$1"
        local pyproject="$2"

        if ! command -v git >/dev/null 2>&1; then
            error_ "'git' command not found."
            return 1
        fi

        if ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            error_ "The project directory '$root' is not inside a git repository."
            return 1
        fi

        local tag
        tag=$(git -C "$root" describe --tags --abbrev=0 2>/dev/null) || tag=""

        if [[ -z "$tag" ]]; then
            tag=$(git -C "$root" tag --sort=-v:refname | head -n1)
        fi

        if [[ -z "$tag" ]]; then
            error_ "No tags found in git repository."
            return 1
        fi

        local raw="$tag"

        if [[ "$raw" == v* ]]; then
            raw="${raw#v}"
        fi
        raw="${raw#.}"

        if ! is_plain_version "$raw"; then
            error_ "Latest tag '$tag' does not look like a version (0.1.2, v0.1.2, or v.0.1.2)."
            return 1
        fi

        local old_ver
        old_ver=$(get_current_version "$pyproject")

        update_pyproject_version "$pyproject" "$raw" || {
            error_ "Failed to update version in pyproject.toml"
            return 1
        }

        if [[ -n "$old_ver" ]]; then
            done_ "Version updated from $old_ver to $raw (from git tag '$tag')."
        else
            done_ "Version set to $raw (from git tag '$tag')."
        fi
    }

    if [[ "$#" -eq 2 && "$1" == "--from" && "$2" == "git" ]]; then
        set_version_from_git "$root" "$pyproject"
        return $?
    fi

    local argc="$#"

    if [[ "$argc" -eq 0 ]]; then
        local current
        current=$(get_current_version "$pyproject")
        if [[ -z "$current" ]]; then
            error_ "Could not find version in pyproject.toml"
            return 1
        fi
        echo "$current"
        return 0
    fi

    local arg1="$1"

    if [[ "$argc" -eq 1 && "$arg1" != "up" && "$arg1" != "down" ]]; then
        if ! is_plain_version "$arg1"; then
            error_ "Invalid version format: '$arg1'. Expected something like '0.1.3' or '1.2.3.4'."
            return 1
        fi

        local old_ver
        old_ver=$(get_current_version "$pyproject")
        update_pyproject_version "$pyproject" "$arg1" || {
            error_ "Failed to update version in pyproject.toml"
            return 1
        }

        if [[ -n "$old_ver" ]]; then
            done_ "Version updated from $old_ver to $arg1"
        else
            done_ "Version set to $arg1"
        fi
        return 0
    fi

    if [[ "$argc" -eq 2 && ( "$arg1" == "up" || "$arg1" == "down" ) ]]; then
        local dir="$arg1"
        local kind="$2"

        case "$kind" in
            patch|minor|major)
                ;;
            *)
                error_ "Invalid version kind: '$kind'. Use: patch, minor, or major."
                return 1
                ;;
        esac

        local current
        current=$(get_current_version "$pyproject")
        if [[ -z "$current" ]]; then
            error_ "Could not find version in pyproject.toml"
            return 1
        fi

        local new_version
        new_version=$(bump_version "$current" "$kind" "$dir") || return 1

        update_pyproject_version "$pyproject" "$new_version" || {
            error_ "Failed to update version in pyproject.toml"
            return 1
        }

        if [[ "$dir" == "up" ]]; then
            done_ "Version bumped ($kind) from $current to $new_version"
        else
            done_ "Version decremented ($kind) from $current to $new_version"
        fi
        return 0
    fi

    error_ "Usage:"
    echo "  py version                       # print current version"
    echo "  py version up   patch|minor|major"
    echo "  py version down patch|minor|major"
    echo "  py version 0.1.3                # set version directly"
    echo "  py version --from git           # set version from latest git tag"
    return 1
}

