fullname=$(readlink -f "$0")

system_binary=$(
    which -a "@name@" \
    | xargs readlink -f \
    | grep -v "$fullname" \
    | head -1
)

if [[ -x $system_binary ]]; then
    exec "$system_binary" "$@"
else
    exec "@package@/bin/@name@" "$@"
fi
