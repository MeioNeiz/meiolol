#!/bin/sh
# On the web server, as root through sudo: the forced command of the gpu-box's accounts
# key (user meiolol, authorized_keys; one sudoers line; docs/data-safety.md "Logins
# backup"). A consistent copy of the logins (accounts.db) on stdout, made as the API's own
# user, for deploy/accounts-pull.sh
set -eu
cd /
exec runuser -u meiolol-api -- /usr/local/bin/meiolol account backup --data /var/lib/meiolol-api
