#!/bin/sh
# On the web server: the forced command of the Mac's training upload key (user meiolol,
# authorized_keys; docs/hosting.md). Reads a gzipped tar of the whole training view
# (deploy/lab-push.sh) and makes it the one nginx serves at /admin/training/: current/ is
# a symlink swapped atomically, so a page never reads a half-written upload.
# The Draft tester's lab models (draft-*.json, lane-*.json, *-model.bin, with .gz for
# gzip_static) also go in current/tester/, which the private site serves as
# /private/lab/ through a symlink (the box's private/ upload excludes it), only while
# /private sends a visitor without a login to the login page: a draft win chance is never
# public
set -eu
d=/var/www/meiolol-training
p=/var/www/meiolol/private
new=$d/v$(date +%s%N)
mkdir "$new"
tar -xzf - -C "$new" --no-same-owner --no-same-permissions
mkdir "$new/tester"
for f in "$new"/draft-*.json "$new"/lane-*.json "$new"/*-model.bin; do
    [ -f "$f" ] || continue
    ln "$f" "$new/tester/"
    gzip -c "$f" > "$new/tester/${f##*/}.gz"
done
chmod -R a+rX "$new"
ln -sfn "$new" "$d/current.tmp"
mv -T "$d/current.tmp" "$d/current"
for v in "$d"/v*; do [ "$v" = "$new" ] || rm -rf "$v"; done
gate=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 https://meio.lol/private || true)
if [ -d "$p" ] && [ "$gate" = 302 ]; then
    ln -sfn "$d/current/tester" "$p/lab"
else
    rm -f "$p/lab"
fi
