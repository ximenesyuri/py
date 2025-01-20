function exec_(){
    local something=$1
    shift
    local env=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--from) env="$2"; shift 2;;
            *) shift;;
        esac
    done

    local venv=$(venv_ "$env")
    source "$venv/bin/activate"

    if [[ -f $something ]]; then
        python3 "$something"
    else
        eval "$something"
    fi

    deactivate
}
