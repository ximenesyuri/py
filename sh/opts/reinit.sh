function reinit_(){
    local env=${1:-}
    local venv=".venv${env:+.${env}}"
    if $(find_ dir $venv); then
        venv=$(find_ dir $venv)
        read -p "Are you sure you want to recreate '$venv'? [y/n] " response
        if [[ $response =~ ^[Yy]$ ]]; then
            rm -rf "$venv"
            python3 -m venv "$venv"
        fi
    else
        echo "error: '$env' is not initialized."
        echo "info: initialize it with 'py init $env'"
        return 1
    fi   
}
