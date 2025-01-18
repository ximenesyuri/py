function delete(){
    local env=$1
    local req_file="requirements${env:+.${env}}.txt"
    local line

    echo "Deps in '$req_file'."
    nl "$req_file"
    echo "Enter the number to delete it:"
    read -e -r -p "> " line

    if [[ $line =~ ^[0-9]+$ ]]; then
        sed -i "${line}d" "$req_file"
    else
        echo "Invalid line number."
    fi   
}
