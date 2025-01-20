function uninstall_(){
    local packages=()
    local env=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --to) env="$2"; shift 2;;
            *) packages+=("$1"); shift;;
        esac
    done

    local venv=$(venv_ "$env")
    source "$venv/bin/activate"
    for pkg in "${packages[@]}"; do
        pip uninstall -y "$pkg"
    done
    deactivate  
}
