#!/bin/sh
# On the web server, as root through sudo: the forced command of the box's cache-version
# key (user meiolol, authorized_keys; one sudoers line; docs/hosting.md). Reads the
# renderer's data version (deploy/cache-version.sh) into meiolol-version.conf, which
# meiolol.conf's proxy_cache_key uses, and reloads nginx
set -eu
read -r v
case $v in *[!0-9a-f]*) exit 2 ;; esac
[ ${#v} -eq 16 ] || exit 2
f=/etc/nginx/meiolol-version.conf
cp "$f" "$f.prev"
# shellcheck disable=SC2016 # nginx variables, not shell ones
printf 'map $host $meiolol_version { default %s; }\n' "$v" > "$f.tmp"
mv "$f.tmp" "$f"
if ! nginx -t -q; then
    mv "$f.prev" "$f"
    exit 1
fi
systemctl reload nginx
