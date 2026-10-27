#!/usr/bin/env bash
# VM4 (docs/plan/vm.md): meiolol's web side on C01, what jomify runs for it today: nginx
# behind the Cloudflare Tunnel (cloudflared, tunnel meiolol-c01, token vault
# meiolol/essex-vm TUNNEL_TOKEN), the Your games API, traffic counting, and user meiolol
# with the forced-command keys. Keys the box used to jomify are made anew on C01 for
# localhost aliases of the same names, so the web loop and cache-version.sh run as they
# are; the Mac's training and the gpu-box's accounts keys are jomify's lines, unchanged.
# Repeatable; files from HEAD, secrets from jomify straight to C01, never printed.
#   deploy/vm-web.sh          install
#   deploy/vm-web.sh data     the same, plus the site, training view, traffic history
#                             and API data from jomify (VM6: with jomify's API stopped)
set -euo pipefail

HOST=essex-vm
ROOT=$(cd "$(dirname "$0")/.." && pwd)
stage=/home/jacob/vm-web-stage
with_data=0
[[ ${1:-} == data ]] && with_data=1
files=(deploy/nginx/meiolol.conf deploy/systemd/meiolol-api.service
    deploy/systemd/meiolol-api-reload.path deploy/systemd/meiolol-api-reload.service
    deploy/systemd/meiolol-traffic.service deploy/systemd/meiolol-traffic.timer
    deploy/traffic.sh deploy/cache-version-receive.sh deploy/training-receive.sh
    deploy/accounts-send.sh)

ssh "$HOST" "rm -rf $stage && mkdir -m 700 $stage"
git -C "$ROOT" archive HEAD "${files[@]}" | ssh "$HOST" "tar -x -C $stage"
ssh jomify 'sudo tar -C /etc/nginx -cf - meiolol-admin-token.conf meiolol-desktop-key.conf \
    meiolol-version.conf' | ssh "$HOST" "tar -x -C $stage"
vault get meiolol/essex-vm TUNNEL_TOKEN | ssh "$HOST" "umask 077 && cat > $stage/tunnel-token"
if (( with_data )); then
    ssh jomify 'sudo tar -C /var -cf - www/meiolol www/meiolol-training www/meiolol-ops \
        lib/meiolol-api lib/meiolol-traffic' \
        | ssh "$HOST" "mkdir $stage/data && tar -x -C $stage/data"
fi

# C01's own keys for the box's aliases, and user meiolol's authorized_keys
ssh "$HOST" "bash -s" "$stage" <<'EOF'
set -euo pipefail
st=$1
keys=$st/authorized_keys
: > "$keys"
for k in web exchange cache; do
    f=$HOME/.ssh/meiolol_$k
    [[ -f $f ]] || ssh-keygen -q -t ed25519 -N '' -C "c01->meiolol-$k" -f "$f"
    if ! grep -q "^Host meiolol-$k\$" ~/.ssh/config; then
        printf '\nHost meiolol-%s\n  HostName 127.0.0.1\n  User meiolol\n' "$k" >> ~/.ssh/config
        printf '  IdentityFile %s\n  IdentitiesOnly yes\n' "$f" >> ~/.ssh/config
    fi
    case $k in
        web) cmd='/usr/bin/rrsync /var/www/meiolol' ;;
        exchange) cmd='/usr/bin/rrsync /var/lib/meiolol-api/exchange' ;;
        cache) cmd='sudo -n /usr/local/bin/meiolol-cache-version' ;;
    esac
    echo "command=\"$cmd\",restrict $(cat "$f.pub")" >> "$keys"
done
ssh-keygen -F 127.0.0.1 > /dev/null \
    || ssh-keyscan -t ed25519 127.0.0.1 2> /dev/null >> ~/.ssh/known_hosts
EOF
ssh jomify 'sudo cat /home/meiolol/.ssh/authorized_keys' \
    | grep -E ' (mac->meiolol-training|gpu-box->meiolol-accounts)$' \
    | ssh "$HOST" "cat >> $stage/authorized_keys"

# As root: the sudo password, then the script, on stdin (sudo reads one line)
{ printf '%s\n' "$(vault get meiolol/essex-vm SUDO_PASSWORD)"; cat <<'EOF'
set -euo pipefail
st=$1 with_data=$2
export DEBIAN_FRONTEND=noninteractive
if [[ ! -f /etc/apt/sources.list.d/cloudflared.list ]]; then
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
        -o /usr/share/keyrings/cloudflare-main.gpg
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared noble main' \
        > /etc/apt/sources.list.d/cloudflared.list
    apt-get update -qq
fi
apt-get install -y -qq nginx cloudflared jq > /dev/null

id meiolol > /dev/null 2>&1 || useradd -m -s /bin/bash meiolol
id meiolol-api > /dev/null 2>&1 \
    || useradd -r -d /var/lib/meiolol-api -s /usr/sbin/nologin meiolol-api
id meiolol-traffic > /dev/null 2>&1 \
    || useradd -r -M -d /nonexistent -s /usr/sbin/nologin meiolol-traffic
usermod -aG meiolol-api meiolol
install -d -o meiolol -g meiolol -m 775 /var/www/meiolol /var/www/meiolol-training
install -d -o meiolol-traffic -g meiolol-traffic -m 755 /var/www/meiolol-ops
install -d -o meiolol-api -g meiolol-api -m 750 /var/lib/meiolol-api
install -d -o meiolol -g meiolol-api -m 2770 /var/lib/meiolol-api/exchange
install -d -o meiolol -g meiolol-api -m 775 /var/lib/meiolol-api/exchange/curves
install -d -o www-data -g root -m 700 /var/cache/nginx/meiolol

if (( with_data )); then
    d=$st/data
    rsync -a --delete "$d/www/meiolol/" /var/www/meiolol/
    rsync -a --delete "$d/www/meiolol-training/" /var/www/meiolol-training/
    rsync -a --delete "$d/www/meiolol-ops/" /var/www/meiolol-ops/
    systemctl stop meiolol-api meiolol-api-reload.path 2> /dev/null || true
    rsync -a --delete "$d/lib/meiolol-api/" /var/lib/meiolol-api/
    for f in /var/lib/meiolol-api/*.db; do
        [[ -e $f ]] || continue
        r=$(sqlite3 "$f" 'PRAGMA quick_check' 2>&1 | head -n 3)
        echo "quick_check $f: $r"
        [[ $r == ok ]] || exit 1
    done
    install -d -o meiolol-traffic -g meiolol-traffic -m 755 /var/lib/meiolol-traffic
    rsync -a --delete "$d/lib/meiolol-traffic/" /var/lib/meiolol-traffic/
    chown -R meiolol:meiolol /var/www/meiolol /var/www/meiolol-training
    chown -R meiolol-traffic:meiolol-traffic /var/www/meiolol-ops /var/lib/meiolol-traffic
    chown -R meiolol-api:meiolol-api /var/lib/meiolol-api
    x=/var/lib/meiolol-api/exchange
    chown meiolol:meiolol-api "$x"
    chown -R meiolol:meiolol-api "$x/curves"
    [[ ! -e $x/box-forgotten.txt ]] || chown meiolol:meiolol-api "$x/box-forgotten.txt"
fi

install -m 644 "$st/deploy/nginx/meiolol.conf" /etc/nginx/conf.d/meiolol.conf
install -m 600 "$st/meiolol-admin-token.conf" "$st/meiolol-desktop-key.conf" /etc/nginx/
[[ -f /etc/nginx/meiolol-version.conf ]] || install -m 644 "$st/meiolol-version.conf" /etc/nginx/
rm -f /etc/nginx/sites-enabled/default
for p in traffic:traffic cache-version:cache-version-receive \
    training-receive:training-receive accounts-send:accounts-send; do
    install -m 755 "$st/deploy/${p#*:}.sh" "/usr/local/bin/meiolol-${p%%:*}"
done
install -m 755 /home/jacob/ml/meiolol/bin/meiolol /usr/local/bin/meiolol
printf 'meiolol ALL=(root) NOPASSWD: /usr/local/bin/meiolol-%s ""\n' cache-version accounts-send \
    > /etc/sudoers.d/meiolol.new
chmod 440 /etc/sudoers.d/meiolol.new
visudo -cqf /etc/sudoers.d/meiolol.new && mv /etc/sudoers.d/meiolol.new /etc/sudoers.d/meiolol
install -d -o meiolol -g meiolol -m 700 /home/meiolol/.ssh
install -o meiolol -g meiolol -m 600 "$st/authorized_keys" /home/meiolol/.ssh/authorized_keys
for u in api.service api-reload.path api-reload.service traffic.service traffic.timer; do
    install -m 644 "$st/deploy/systemd/meiolol-$u" /etc/systemd/system/
done
systemctl daemon-reload

nginx -t -q
systemctl enable -q --now nginx
systemctl reload nginx
systemctl enable -q --now meiolol-api meiolol-api-reload.path meiolol-traffic.timer
systemctl restart meiolol-api
systemctl is-enabled -q cloudflared 2> /dev/null \
    || cloudflared service install "$(cat "$st/tunnel-token")"
rm -rf "$st"
systemctl is-active nginx meiolol-api cloudflared | paste -sd' ' -
EOF
} | ssh "$HOST" "sudo -S -p '' bash -s $stage $with_data"
