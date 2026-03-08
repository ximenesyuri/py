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
        ".env"
    )

    declare -A OPTS=(
        [help]="h --help"
        [init]="I"
        [reinit]="R"
        [registry]=""
        [add]="a"
        [remove]="rm"
        [install]="i"
        [uninstall]="u"
        [update]="U up"
        [shell]="sh activate"
        [exec]="x run"
        [dot]="."
        [list]="ls"
        [version]="v"
        [build]="b"
        [push]="publish p"
    )

    declare -A FLAGS=(
        [--recursive]="-r --rec --recursive"
        [--from]="-f --from"
        [--to]="-t --to"
        [--registry]="-R --reg --registry"
        [--env]="-e --environment -v --venv"
        [--path]="-p --path"
        [--version]="-v --version"
        [--branch]="-b --branch"
        [--commit]="-c --commit"
        [--protocol]="--protocol"
        [--no-deps]="--no-deps"
    )

    if [[ -z "$1" ]]; then
        source ${BASH_SOURCE%/*}/sh/help.sh
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

source ${BASH_SOURCE%/*}/src/completion
source ${BASH_SOURCE%/*}/src/aliases

