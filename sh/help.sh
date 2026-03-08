function help_() {
    cat <<'EOF'
USAGE:
    py [action] [flags]

ACTIONS:
    I, init ................. initialize an environment
    R, reinit ............... re-initialize an environment
    a, add  ................. add dependencies to a requirements file
    d, del, delete .......... delete dependencies from a requirements file
    i, ins, install ......... install packages
    u, uns, uninstall ....... uninstall packages
    U, up, update ........... update packages
    x, exec, run ............ execute some file or command
    ., dot .................. enter dependency directory shell
    ls, list ................ list dependencies and status
    b, build ................ build package
    p, push, publish ........ publish built package
    sh, shell ............... activate environment shell
    v, version .............. bump project version
    registry ................ manage registries (TBA)

FLAGS:
    -f, --from .................... exec action from somewhere (registry/env)
    -t, --to ...................... exec action into somewhere (env)
    -e, --env, --environment ...... exec action in some environment
    -r, --rec, --recursive ........ exec action recursively
    -p, --path .................... exec action from some path 
    -R, --reg, --registry ......... exec action for some registry
    --no-deps ..................... do not install dependencies
    --branch ...................... branch for VCS dependencies
    --commit ...................... commit for VCS dependencies
    --protocol .................... protocol for VCS dependencies (https|ssh)

Examples:
    py init
    py add requests
    py install -r requirements.txt
    py exec main.py
EOF
}

