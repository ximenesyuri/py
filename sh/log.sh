local RED_="\033[31m"
local GREEN_="\033[32m"
local YELLOW_="\033[33m"
local BLUE_="\033[34m"
local MAGENTA_="\033[35m"
local RESET_="\033[0m"

function log_(){
    echo -e "${BLUE_}log:${RESET_}" "$@"
}

function error_() {
    echo -e "${RED_}error:${RESET_}" "$@"
}

function done_() {
    echo -e "${GREEN_}done:${RESET_}" "$@"
}

function info_() {
    echo -e "${MAGENTA_}info:${RESET_}" "$@"
}

function warn_() {
    echo -e "${YELLOW}warn:${RESET_}" "$@"
}

