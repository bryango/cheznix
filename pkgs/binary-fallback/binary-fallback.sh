target=$(
    which -a "@name@" \
    | grep -v "^$0$" \
    | head -1
)

if [[ -x $target ]]; then
    exec "$target" "$@"
else
    exec "@name@" "$@"
fi
