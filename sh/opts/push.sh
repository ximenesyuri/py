function push_() {
    if ! inside_; then
        return 1
    fi

    local root
    root=$(find_ root)
    local pyproject="$root/pyproject.toml"
    local registry=""
    local env=""
    local repo_url=""
    local username=""
    local password=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--registry) registry="$2"; shift 2 ;;
            -e|--env)      env="$2";      shift 2 ;;
            -u|--username|--user) username="$2"; shift 2 ;;
            -p|--password|--pass) password="$2"; shift 2 ;;
            --repo-url|--url) repo_url="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: py push [options]"
                echo "Publish the built package to a registry"
                echo ""
                echo "Options:"
                echo "  -r, --registry <name>  Registry name (pypi|testpypi|URL)"
                echo "  -e, --env <env>        Specify environment"
                echo "  -u, --username <user>  Username for authentication"
                echo "  -p, --password <pass>  Password for authentication"
                echo "  --repo-url <url>       Direct repository URL"
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

    if [[ ! -d "$root/dist" ]] || [[ -z "$(ls -A "$root/dist")" ]]; then
        error_ "No built packages found. Run 'py build' first."
        return 1
    fi

    # Activate environment
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

    # Extract package info
    local package_name package_version package_summary
    package_name=$(awk -F' = ' '/^[[:space:]]*name[[:space:]]*=/ {
        gsub(/^[ "]*/, "", $2); gsub(/[ ",]*/, "", $2); print $2; exit
    }' "$pyproject")
    package_version=$(awk -F' = ' '/^[[:space:]]*version[[:space:]]*=/ {
        gsub(/^[ "]*/, "", $2); gsub(/[ ",]*/, "", $2); print $2; exit
    }' "$pyproject")
    package_summary=$(awk -F' = ' '/^[[:space:]]*description[[:space:]]*=/ {
        gsub(/^[ "]*/, "", $2); gsub(/[ ",]*/, "", $2); gsub(/,$/, "", $2); print $2; exit
    }' "$pyproject")

    package_name=${package_name:-$(basename "$root")}
    package_version=${package_version:-"0.1.0"}
    package_summary=${package_summary:-""}

    # Determine upload URL
    local upload_url="$repo_url"
    if [[ -n "$registry" && -z "$upload_url" ]]; then
        case "$registry" in
            pypi|pyPi|PyPI) upload_url="https://upload.pypi.org/legacy/" ;;
            testpypi|test)  upload_url="https://test.pypi.org/legacy/" ;;
            *)              upload_url="$registry" ;;
        esac
    fi
    if [[ -z "$upload_url" ]]; then
        upload_url="https://upload.pypi.org/legacy/"
        warn_ "No registry specified, using PyPI by default."
    fi

    # Auth (PyPI token or username/password)
    local curl_auth=()
    local has_auth=false
    if [[ -n "$username" && -n "$password" ]]; then
        curl_auth=(-u "${username}:${password}")
        has_auth=true
    elif [[ -n "$PYPI_API_TOKEN" ]]; then
        curl_auth=(-u "__token__:${PYPI_API_TOKEN}")
        has_auth=true
    fi

    if [[ "$has_auth" == false ]]; then
        warn_ "No authentication provided. You may need to provide credentials."
        warn_ "Use -u/--username and -p/--password, or set PYPI_API_TOKEN environment variable."
    fi

    # Collect dist files
    local dist_files=()
    while IFS= read -r -d '' file; do
        dist_files+=("$file")
    done < <(find "$root/dist" -type f \( -name "*.tar.gz" -o -name "*.whl" \) -print0 2>/dev/null)

    if [[ ${#dist_files[@]} -eq 0 ]]; then
        error_ "No distribution files found in dist/ directory."
        deactivate
        return 1
    fi

    log_ "Publishing package to $upload_url..."

    local upload_success=false
    for dist_file in "${dist_files[@]}"; do
        local filename
        filename=$(basename "$dist_file")

        # Infer filetype for legacy API
        local filetype="sdist"
        local pyversion="source"
        if [[ "$filename" == *.whl ]]; then
            filetype="bdist_wheel"
            pyversion=""
        fi

        # Compute SHA256 digest of the file in bash
        local sha256_digest
        if command -v sha256sum >/dev/null 2>&1; then
            sha256_digest=$(sha256sum "$dist_file" | awk '{print $1}')
        elif command -v shasum >/dev/null 2>&1; then
            sha256_digest=$(shasum -a 256 "$dist_file" | awk '{print $1}')
        else
            error_ "Neither 'sha256sum' nor 'shasum' found. Cannot compute SHA256 digest."
            deactivate
            return 1
        fi

        log_ "Uploading $filename..."

        local curl_output http_code
        curl_output=$(curl -sS -w "\n%{http_code}" \
            "${curl_auth[@]}" \
            -F ":action=file_upload" \
            -F "protocol_version=1" \
            -F "metadata_version=2.1" \
            -F "name=${package_name}" \
            -F "version=${package_version}" \
            -F "summary=${package_summary}" \
            -F "filetype=${filetype}" \
            -F "pyversion=${pyversion}" \
            -F "sha256_digest=${sha256_digest}" \
            -F "content=@${dist_file}" \
            "$upload_url" 2>&1)
        http_code=$(echo "$curl_output" | tail -1)
        curl_output=$(echo "$curl_output" | head -n -1)
        local curl_exit_code=$?

        if [[ $curl_exit_code -eq 0 && ($http_code -eq 200 || $http_code -eq 201) ]]; then
            done_ "Successfully uploaded $filename"
            upload_success=true
        else
            error_ "Failed to upload $filename"
            error_ "HTTP status code: $http_code"
            if [[ $http_code -eq 401 ]]; then
                error_ "Authentication failed. Check your credentials or API token."
            elif [[ $http_code -eq 403 ]]; then
                error_ "Forbidden. You may not have permission to upload this package."
            elif [[ $http_code -eq 400 ]]; then
                error_ "Bad request. Check package name, version, dist file, and that this version isn’t already uploaded."
                echo "$curl_output" | tail -10
            elif [[ $http_code -eq 405 ]]; then
                error_ "Method not allowed – often caused by wrong fields to the legacy endpoint."
            else
                error_ "Response from server:"
                echo "$curl_output" | tail -10
            fi
        fi
    done

    if [[ "$upload_success" == true ]]; then
        done_ "Package published successfully."
    else
        error_ "Failed to publish package."
        deactivate
        return 1
    fi

    deactivate
}

