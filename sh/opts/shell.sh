function shell(){
    local env=${1:-}
    local venv=".venv${env:+.${env}}"
    source "$venv/bin/activate"   
}
