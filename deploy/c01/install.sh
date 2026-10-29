#!/usr/bin/env bash
# C01's data disk pieces (docs/hosting.md "Data disk"): meiolol-disk and its service, the
# Megatron fstab lines, and the empty mount points made immutable, so nothing can write
# to / under them while a share or the disk is down. Run from the Mac:
#   deploy/c01/install.sh
# Never restarts meiolol-disk.service: its stop unmounts the data under everything
set -euo pipefail
HOST=${MEIOLOL_HOST:-essex-vm}
mounts=(srv/meiolol srv/megatron srv/megatron-backups)

if [[ ${1:-} != --here ]]; then
    here=$(cd "$(dirname "$0")" && pwd)
    tmp=$(ssh "$HOST" mktemp -d)
    scp -q "$here"/{install.sh,meiolol-disk,meiolol-disk.service,fstab} "$HOST:$tmp/"
    vault get meiolol/essex-vm SUDO_PASSWORD \
        | ssh "$HOST" "head -1 | sudo -S -p '' -v && sudo bash $tmp/install.sh --here $tmp; rc=\$?; rm -rf $tmp; exit \$rc"
    # What deploy/health.sh checks are mounted
    list=$(printf '/%s ' "${mounts[@]}")
    ssh "$HOST" "grep -q '^MEIOLOL_MOUNTS=' ml/meiolol/host.env \
        || echo 'MEIOLOL_MOUNTS=\"${list% }\"' >> ml/meiolol/host.env"
    exit
fi

dir=$2
install -m 755 "$dir/meiolol-disk" /usr/local/sbin/meiolol-disk
install -m 644 "$dir/meiolol-disk.service" /etc/systemd/system/meiolol-disk.service
# Ours replace any earlier meiolol lines (comments "# meiolol", mounts on /srv/megatron*)
awk '!/^# meiolol/ && $2 !~ /^\/srv\/megatron/' /etc/fstab > /etc/fstab.new
cat "$dir/fstab" >> /etc/fstab.new
if cmp -s /etc/fstab /etc/fstab.new; then
    rm /etc/fstab.new
else
    cp -p /etc/fstab /etc/fstab.bak
    chmod 644 /etc/fstab.new
    mv /etc/fstab.new /etc/fstab
    echo "fstab updated (old one in /etc/fstab.bak)"
fi
systemctl daemon-reload
systemctl enable -q meiolol-disk.service
# The mount points as they are on /, under whatever is mounted on them
root=$(mktemp -d)
mount --bind / "$root"
for m in "${mounts[@]}"; do
    mkdir -p "$root/$m"
    if [[ -n $(ls -A "$root/$m") ]]; then
        echo "/$m: files under the mount point on /, left mutable: move them off first"
    else
        chattr +i "$root/$m"
    fi
done
umount "$root"
rmdir "$root"
echo "installed: meiolol-disk, meiolol-disk.service, fstab lines, immutable ${mounts[*]}"
