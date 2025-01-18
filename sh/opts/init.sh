function init(){
    local env=${1:-}
    local venv=".venv${env:+.${env}}"
    local venv="$(find_ dir $venv)" 
    if [[ -n "$venv" ]]; then
        venv=$(find_ dir $venv)
        error_ "The environment '$env' was already initialized."
        return 1
    else
        log_ "Initializing environment '$env'..."
        python3 -m venv "$venv"
        gitgnore=$(find_ file .gitignore)
        if [[ -z "$gitignore" ]]; then
            touch .gitignore
        fi
        for ignore in ${IGNORE[@]}; do
            if ! grep -qx "$ignore" .gitignore; then
                echo "dist/" >> .gitignore
            fi 
        done
        if ! grep -qx "$ignore" .gitignore; then
            echo "$venv" >> .gitignore
        fi
        done_ "The environment '$env' has been initalized."
    fi
}
