#!/bin/sh
# On the web server: the forced command of the Mac's training upload key (user meiolol,
# authorized_keys; docs/hosting.md). Reads a gzipped tar of the whole training view
# (deploy/lab-push.sh) and makes it the one nginx serves at /admin/training/: current/ is
# a symlink swapped atomically, so a page never reads a half-written upload
set -eu
d=/var/www/meiolol-training
new=$d/v$(date +%s%N)
mkdir "$new"
tar -xzf - -C "$new" --no-same-owner --no-same-permissions
chmod -R a+rX "$new"
ln -sfn "$new" "$d/current.tmp"
mv -T "$d/current.tmp" "$d/current"
for v in "$d"/v*; do [ "$v" = "$new" ] || rm -rf "$v"; done
