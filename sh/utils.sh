pyproject_() {
        echo "
[project]
name = \"some_name\"
version = \"0.0.0\"
description = \"some description\"
readme = \"README.md\"
requires-python = \">=3.6\"
license = {text = \"some_license\"}
authors = [
    {name = \"your_name\", email = \"your@email.com\"},
]

[build-system]
requires = [\"setuptools>=61.0\", \"wheel\"]
build-backend = \"setuptools.build_meta\"
        "
    }

find_() {
    local kind=$1
    local to_find=$2
    local dir=$PWD

    while [[ "$dir" != "/" ]] || 
          [[ ! -f "$dir/pyproject.toml" ]]; do
        case $kind in 
            f|file)
                if [[ -f "$dir/$to_find" ]]; then
                    echo "$dir/$to_find"
                    return 0
                fi
                dir=$(dirname "$dir")
                continue
                ;;
            d|dir)
                if [[ -d "$dir/$to_find" ]]; then
                    echo "$dir/$to_find"
                    return 0
                fi
                dir=$(dirname "$dir")
                continue
                ;;
            r|root)
                if [[ -f "$dir/pyproject.toml" ]]; then
                    echo "$dir"
                    return 0
                fi
                dir=$(dirname "$dir")
                continue
                ;;
            *)
                echo "error: find_: option not valid: '$kind'."
                return 1
                ;;
        esac
    done
    return 1
}

function contains_(){
    if [[ -n "$(cat "$2" | grep "$1")" ]]; then
        return 0
    else
        return 1
    fi
}
