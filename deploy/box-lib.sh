# shellcheck shell=bash
# Helpers for the box's scripts (box.sh copies it beside them): `. bin/box-lib.sh` from
# ~/ml/meiolol

# One line in data/deploys.tsv, the admin page's Deploys tab (docs/hosting.md "Deploy
# events"): unix time, the commit, step, status, detail (tabs in it become spaces)
#   deploy_event SHA STEP STATUS [DETAIL]
deploy_event() {
    local f=data/deploys.tsv detail=${4:-}
    [[ -s $f ]] || printf 'time\tsha\tstep\tstatus\tdetail\n' > "$f"
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$1" "$2" "$3" "${detail//$'\t'/ }" >> "$f"
}

# The commit of the newest deploy (DEPLOYED: deploy/box.sh sync)
deployed_sha() { tail -n 1 DEPLOYED 2> /dev/null | cut -d' ' -f1; }
