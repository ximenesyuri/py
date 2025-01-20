function install_() {
    local packages=()
    local registry="pypi"
    local env=""

    if ! inside_; then
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            "${FLAGS[--from]}"|"${FLAGS[--registry]}") registry="$2"; shift 2;;
            "${FLAGS[--to]}"|${FLAGS[--env]}) env="$2"; shift 2;;
            *) packages+=("$1"); shift;;
        esac
    done

    if ! has_env_ "$env"; then
        error_ "The environment '$env' was not initialized."
        info_ "Try 'py init [$env]'."
        return 1
    fi
    activate_ $env 
    for pkg in "${packages[@]}"; do
        pip install "$pkg" --extra-index-url "https://$registry"
    done
    deactivate
}

