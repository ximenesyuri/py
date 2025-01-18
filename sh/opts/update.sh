function update(){
    local packages=()
    local env=""
    local update_all=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--from) env="$2"; shift 2;;
            -R|--recursive) update_all=true; env="$2"; shift 2;;
            *) packages+=("$1"); shift;;
        esac
    done

    local venv=$(venv_ "$env")
    if [ -z "$venv" ]; then
        echo "error: '$env' is not initialized."
        echo "info: initialize it with 'py init $env'"
        return 1
    fi

    source "$venv/bin/activate"

    if $update_all; then
        outdated_packages=$(pip list -v --outdated --format=columns | awk 'NR>2 { print $1 }')
        if [ -z "$outdated_packages" ]; then
            echo "All packages in env '$env' are up-to-date."
        else
            echo "$outdated_packages" | xargs -n1 pip install -v -U
        fi
    else
        for pkg in "${packages[@]}"; do
            pip install -v --upgrade "$pkg"
        done
    fi
    deactivate  
}
