#! /bin/bash

py() {
    source ${BASH_SOURCE%/*}/sh/log.sh
    source ${BASH_SOURCE%/*}/sh/utils.sh
    declare -a PY_IGNORE=(
        "build/"
        "dist/"
        "__pycache__/"
        "*.py[oc]"
        "wheels/"
        "*.egg-info"
    )

    declare -A OPTS=(
        [help]="h --help"
        [init]="I"
        [reinit]="R"
        [registry]=""
        [add]="a"
        [delete]="d del"
        [install]="i ins"
        [uninstall]="u uns"
        [update]="U up"
        [shell]="s sh act activate"
        [exec]="x execute run"
    )

    declare -A FLAGS=(
        [--recursive]="-R --rec --recursive"
        [--from]="-f --from"
        [--to]="-t --to"
        [--registry]="-r --reg --registry"
        [--env]="-e --environment -v --venv"
        [--path]="-p --path"
    )

    if [[ -z "$1" ]]; then
        help_
        return 0
    fi

    declare -a opt_aliases=()
    local match_opt=""
    for opt in ${!OPTS[@]}; do
        opt_aliases="${OPTS[$opt]}"
        for alias in ${opt_aliases[@]}; do
            if [[ "$1" == "$alias" ]] ||
               [[ "$1" == "$opt" ]]; then
                local match_opt="true"
                source ${BASH_SOURCE%/*}/sh/opts/${opt}.sh
                eval "\"${opt}_\" ${@:2}"
                if [[ ! "$?" == "0" ]]; then
                    return 1
                fi
                break 2
            fi
        done
    done
    if [[ ! "$match_opt" == "true" ]]; then 
        error_ "Option '$1' not defined."
        return 1
    fi    
}

