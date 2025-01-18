function install(){    
    if [[ "$1" == "-R" || "$1" == "--recursive" ]]; then
        local env=${2:-}
        local venv=$(venv_ "$env")
        
        source "$venv/bin/activate"
        pip install -r "requirements${env:+.${env}}.txt"
        deactivate
    else
        local env=""
        local packages=()

        while [[ $# -gt 0 ]]; do
            case $1 in
                --to) env="$2"; shift 2;;
                *) packages+=("$1"); shift;;
            esac
        done

        local venv=".venv${env:+.${env}}"
        source "$venv/bin/activate"
        pip install "${packages[@]}"
        deactivate
    fi
}
