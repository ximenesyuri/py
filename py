#! /bin/bash

py() {
    local cmd=$1
    shift

    case $cmd in
        init)
            local env=${1:-}
            local venv=".venv${env:+.${env}}"
            local req_file="requirements${env:+.${env}}.txt"
            
            [ ! -d "$venv" ] && python3 -m venv "$venv"
            [ ! -f "$req_file" ] && touch "$req_file"
            
            echo -e "dist/\nbuild/\n$venv" > .gitignore
            ;;
        
        reinit)
            local env=${1:-}
            local venv=".venv${env:+.${env}}"

            read -p "Are you sure you want to recreate $venv? [y/n] " response
            if [[ $response =~ ^[Yy]$ ]]; then
                rm -rf "$venv"
                python3 -m venv "$venv"
            fi
            ;;

        registry)
            local action=$1
            shift

            case $action in
            l|ls|list)
                local env=$1
                yq eval '.registries | to_entries | map(select(.value.environments | index("'${env}'"))) | .[].key' py.yml
                ;;
            n|new)
                echo "Registry creation not implemented."
                ;;
            r|rm|remove)
                echo "Registry removal not implemented."
                ;;
            esac
            ;;

        a|add)
            local packages=()
            local registry="pypi"
            local env=""

            while [[ $# -gt 0 ]]; do
                case $1 in
                    -f|--from) registry="$2"; shift 2;;
                    -t|--to) env="$2"; shift 2;;
                    *) packages+=("$1"); shift;;
                esac
            done

            local req_file="requirements${env:+.${env}}.txt"
            
            for pkg in "${packages[@]}"; do
                if [[ "$registry" == "github" ]]; then
                    local owner_repo_branch=(${pkg//[@]/ })
                    local owner_repo="${owner_repo_branch[0]}"
                    local branch="${owner_repo_branch[1]}"

                    if [[ -n "$PY_YML_GLOBAL" ]]; then
                        if [[ -z "$branch" ]]; then
                            branch=$(yq eval '.git.github.branch' py.yml)
                            if [[ "$branch" == "null" ]]; then
                                branch="main"
                            fi
                        fi
                    else
                        branch="main"
                    fi

                    pkg="git+https://github.com/$owner_repo.git@$branch"
                fi
                function has_(){
                    if [[ -n "$(cat "$2" | grep "$1")" ]]; then
                        return 0
                    else
                        return 1
                    fi
                }

                if $(has_ "$pkg" "$req_file"); then
                    echo "error: The package '$pkg' was already included in '$req_file'."
                    return 1
                fi
                echo "$pkg" >> "$req_file"
            done
            ;; 

        i|install)
            if [[ "$1" == "-R" || "$1" == "--recursive" ]]; then
                local env=${2:-}
                local venv=".venv${env:+.${env}}"
                
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
            ;;

        r|rm|remove)
            local packages=()
            local env=""

            while [[ $# -gt 0 ]]; do
                case $1 in
                    --to) env="$2"; shift 2;;
                    *) packages+=("$1"); shift;;
                esac
            done

            local venv=".venv${env:+.${env}}"
            source "$venv/bin/activate"
            for pkg in "${packages[@]}"; do
                pip uninstall -y "$pkg"
            done
            deactivate
            ;;

        s|sh|shell)
            local env=${1:-}
            local venv=".venv${env:+.${env}}"

            source "$venv/bin/activate"
            ;;

        x|exec)
            local something=$1
            shift
            local env=""

            while [[ $# -gt 0 ]]; do
                case $1 in
                    -f|--from) env="$2"; shift 2;;
                    *) shift;;
                esac
            done

            local venv=".venv${env:+.${env}}"
            source "$venv/bin/activate"

            if [[ -f $something ]]; then
                python3 "$something"
            else
                eval "$something"
            fi

            deactivate
            ;;

        *)
            echo "Unknown command: $cmd"
            ;;
    esac
}
