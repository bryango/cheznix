system_binary=$(
    which -a "@name@" \
    | grep -v "$0" \
    | head -1
)

if [[ -x $system_binary ]]; then
    exec "$system_binary" "$@"
else
    exec "@package@" "$@"
fi
