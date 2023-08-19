#!/bin/bash
# v2ray & cow

outbounds="@outbounds@"
routings="@routings@"

[[ -n $1 ]] && outbounds=$1 && shift
[[ ! $# -eq 0 ]] && routings=$1

## this is the function that gets passed to tmux
function core_function {
    outbounds=$1
    routings=$2

    set -x
    trap 'zsh -i; trap - EXIT' EXIT HUP INT QUIT PIPE TERM

    V2RAY_OUTBOUND_CHAIN=$outbounds \
    V2RAY_ROUTING_SETUP=$routings \
    v2config > /tmp/v2config.json

    v2ray run -c /tmp/v2config.json \
        | sed --unbuffered -E 's|v2ray.com/||g' \
        | sed -E 's/^[0-9]+[^ ]+ //g'
}

## convert it to string
export -f core_function

## pass as a string
core_function=$(printenv BASH_FUNC_core_function%%)


function kill_families {
    read -r -a parent_procs <<< "$(
        pgrep "$@" | grep -v "^$$$"
    )"
    for parent in "${parent_procs[@]}"; do
        ## kill child processes
        pkill -9 -P "$parent"
    done
    [[ -n ${parent_procs[*]} ]] && kill -9 "${parent_procs[@]}"
    true
} &>/dev/null

core_app='v2ray'
conflicted=(curl-ipinfo sslocal kcptun-client cow "$core_app")

>&2 echo "## Cleaning up previous sessions ..."
{
    kill_families --full "$(readlink -f "$0")"
    for proc in "${conflicted[@]}";
    do
        kill_families "$proc"
    done

    byobu-tmux kill-session -t "v2ray"
} &>/dev/null
>&2 echo "## Cleaned up."


## set up the byobu session
byobu-tmux new-session -d -s "$core_app" -n "$core_app" \
    bash -c "fn $core_function; fn $outbounds $routings"


>&2 echo "## Checking connection status ..."

for _ in {1..10}; do
    sleep 0.5
    if proxy_status=$(proxychains -q curl-ipinfo); then
        break
    fi
done

proxy_status=$(echo "$proxy_status" \
    | sed -E 's/, /,\n/g' \
    | grep -v -E 'hostname|loc|postal|phone'
)
[[ -z $proxy_status ]] \
    && proxy_status='Possible Failure! No status returned.' \
    && failure=1
echo "$proxy_status"

notify-send "$core_app - $outbounds" \
    "<b>[Info]</b> $proxy_status" \
    --hint=int:transient:1 \
&>/dev/null || true

[[ -n $failure ]] && exit 1 || exit 0
