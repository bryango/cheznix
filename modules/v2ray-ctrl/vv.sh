#!/bin/bash
# v2ray & cow
# shellcheck disable=1090,1091,2034

source "$HOME/.bash_utils"

outbounds=@outbounds@
routings=@routings@

[[ -n $1 ]] && outbounds=$1 && shift
[[ ! $# -eq 0 ]] && routings=$1

# shellcheck disable=2154
init_commands="$set_trap"

core_app='v2ray'
conflicted=(curl-ipinfo sslocal kcptun-client cow "$core_app")
function core-function {
    tr -s ' ' <<- EOF
        V2RAY_OUTBOUND_CHAIN=$outbounds \
        V2RAY_ROUTING_SETUP=$routings \
        v2config > /tmp/v2config.json;
        v2ray run -c /tmp/v2config.json \
            | sed --unbuffered -E 's|v2ray.com/||g' \
            | sed -E 's/^[0-9]+[^ ]+ //g'
EOF
}

########

>&2 echo "## Cleaning up previous sessions ..."

kill-family "$(readlink -f "$0")" "$$" &>/dev/null || true
for proc in "${conflicted[@]}";
do
    # shellcheck disable=2207
    IFS=$'\n' procs=( $(pgrep "$proc") )
    kill -9 "${procs[@]}" &>/dev/null || true
done

byobu kill-session -t "v2ray"
>&2 echo "## Cleaned up."

byobu new-session -d -s "$core_app" -n "$core_app" \
    bash -c "$init_commands; $(core-function "$outbounds")"


>&2 echo "## Checking connection status ..."

sleep .5  # for the connection to be up

counter=0
while [[ "$counter" -lt 3 ]]; do
    if proxy_status=$(proxychains -q curl-ipinfo); then
        break
    else
        counter=$((counter + 1))
        sleep .5
    fi
done

proxy_status=$(echo "$proxy_status" \
    | sed -E -e 's/, /,\n/g' \
    | awk '!/hostname|loc|postal|phone/'
)
[[ -z $proxy_status ]] \
    && proxy_status='Possible Failure! No status returned.' \
    && failure=1
echo "$proxy_status"

notify-send "$core_app - $outbounds" \
    "<b>[Info]</b> $proxy_status" \
    --hint=int:transient:1 \
|| true

