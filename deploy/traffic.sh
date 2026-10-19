#!/usr/bin/env bash
# On the web server, every 5 min (systemd meiolol-traffic.timer, user meiolol-traffic;
# docs/hosting.md): meiolol's own nginx access log (format meiolol_noip, JSON lines, no
# IP addresses) to /var/www/meiolol-ops/traffic.json, which the admin page reads at
# /admin/ops/. Each log file is summarised once per hour bucket and cached by inode with
# the offset read, so a run reads only new lines (a rotation keeps the inode; a .gz is
# read once). Hourly totals go to hourly.tsv, kept 90 days, past the 14 days of logs.
# A browser-agent page view counts as a person only when the same agent also fetched
# /style.css within PAIR_S: every page links it with Cache-Control no-cache, so a browser
# asks for it (200 or 304) on each load, and most bots with a browser's agent never do.
# Pages link with no-referrer, so the CSS request can't name its page: matched by agent,
# one fetch per view. The rest are "unconfirmed" (hours column 6)
# Shape of traffic.json: section 3 of the admin dashboard contract (admin.js reads it)
set -euo pipefail

LOG=${MEIOLOL_TRAFFIC_LOG:-/var/log/nginx/meiolol.access.log}
STATE=${STATE_DIRECTORY:-/var/lib/meiolol-traffic}
OUT=${MEIOLOL_TRAFFIC_OUT:-/var/www/meiolol-ops/traffic.json}
# files2: summaries with the unconfirmed count; files held the older shape
CACHE=$STATE/files2
rm -rf "$STATE/files"
HOURLY=$STATE/hourly.tsv
mkdir -p "$CACHE"
touch "$HOURLY"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

TOP='def top($n): to_entries | sort_by(-.value) | .[:$n] | from_entries;'
# Lines per jq run: its maps of paths (404s are any path a scanner tries) stay small
PIECE_LINES=50000
PAIR_S=60

# Per hour: people's and bot page views, assets, 5xx, bytes, unconfirmed views (browser
# agent, no stylesheet), then counts by status, 404 uri, page uri, referrer domain, agent
# family, render cache status, latency bucket (ms). Page uri and referrer count people only.
# pend: per agent, views waiting for a stylesheet fetch and fetches waiting for a view (a
# big page can be logged after its CSS); a view still waiting at the end stays unconfirmed
SUMMARY=$TOP'
def page: .m == "GET" and (.s == 200 or .s == 304)
    and (.u | test("(/|\\.html)$") or (split("/") | last | contains(".") | not));
# browser-tool: our own `browse` runs, which tag their Chrome UA on meio.lol
def bot: (.a // "") as $a | $a == ""
    or ($a | test("bot|crawl|spider|slurp|curl|wget|python|go-http|httpclient|headless|preview|monitor|browser-tool"; "i"));
def family: (.a // "") as $a |
    if $a == "" then "Empty agent"
    elif bot then
        ([$a | match("[A-Za-z][A-Za-z0-9_.-]*(bot|crawl|crawler|spider|slurp)[A-Za-z0-9_.-]*"; "i")] | first | .string)
        // ([$a | match("browser-tool|curl|wget|python[A-Za-z-]*|go-http-client|[A-Za-z]*httpclient|headless[A-Za-z]*|[A-Za-z]*preview|[A-Za-z]*monitor[A-Za-z]*"; "i")] | first | .string)
        // "Other bot"
    elif ($a | test("Edg/|EdgA/|EdgiOS/")) then "Edge"
    elif ($a | test("OPR/|SamsungBrowser/")) then "Other"
    elif ($a | test("Chrome/|CriOS/")) then "Chrome"
    elif ($a | test("Firefox/|FxiOS/")) then "Firefox"
    elif ($a | test("Safari/")) then "Safari"
    else "Other" end;
def domain: first(((.r // "") | capture("^[A-Za-z][A-Za-z0-9+.-]*://(?<d>[^/:?#@]+)").d | ascii_downcase), "");
def person($h; $u; $d): .hours[$h].u -= 1 | .hours[$h].h += 1 | .hours[$h].pg[$u] += 1
    | if $d != "" and ($d | IN("meio.lol", "www.meio.lol", "meiolol.jomify.lol") | not)
      then .hours[$h].rf[$d] += 1 else . end;
def bucket: (.rt * 1000) as $ms
    | (([1, 2, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 30000]
        | map(select(. >= $ms)) | first) // 60000) | tostring;
reduce (inputs | fromjson? | select(type == "object" and (.t | type) == "number"
        and (.s | type) == "number" and (.u | type) == "string")
    | select(.u | startswith("/admin/") | not)) as $r
  ({from: null, hours: {}, pend: {}};
    ($r.t / 3600 | floor * 3600 | tostring) as $h
    | .from = ([.from, ($r.t | floor)] | map(select(. != null)) | min)
    | .hours[$h] |= (. // {h: 0, b: 0, a: 0, e: 0, by: 0, u: 0, st: {}, nf: {}, pg: {}, rf: {}, ag: {}, rc: {}, lt: {}})
    | .hours[$h].by += ($r.b // 0)
    | .hours[$h].st[$r.s | tostring] += 1
    | if $r.s >= 500 then .hours[$h].e += 1 else . end
    | if $r.s == 404 then .hours[$h].nf[$r.u] += 1 else . end
    | if ($r | page) then
        (if ($r | bot) then .hours[$h].b += 1
         else .hours[$h].u += 1
            | ($r | domain) as $d | ($r.a // "") as $a
            | .pend[$a] |= ((. // {p: [], c: []}) | .c |= map(select(. >= $r.t - $pair)))
            | if (.pend[$a].c | length) > 0 then .pend[$a].c |= .[1:] | person($h; $r.u; $d)
              else .pend[$a].p += [[$r.t, $h, $r.u, $d]] end
         end)
        | .hours[$h].ag[$r | family] += 1
        | .hours[$h].rc[if ($r.c // "") == "" then "static" else $r.c end] += 1
        | .hours[$h].lt[$r | bucket] += 1
      elif $r.s < 400 then .hours[$h].a += 1
        | if $r.u == "/style.css" and ($r | bot | not) then
            ($r.a // "") as $a
            | .pend[$a] |= ((. // {p: [], c: []}) | .p |= map(select(.[0] >= $r.t - $pair)))
            | if (.pend[$a].p | length) > 0 then
                .pend[$a].p[0] as $v | .pend[$a].p |= .[1:] | person($v[1]; $v[2]; $v[3])
              else .pend[$a].c += [$r.t] end
          else . end
      else . end)
| del(.pend)
| .hours |= map_values(.nf |= top(200) | .pg |= top(200) | .rf |= top(200))
'

# Path maps trimmed to the top 200 again after adding, so a cache entry stays bounded
MERGE=$TOP'
def addmap($a; $b): reduce ($b | to_entries[]) as $e ($a // {}; .[$e.key] += $e.value);
def mergeh($a; $b): if $a == null then $b else
    {h: ($a.h + $b.h), b: ($a.b + $b.b), a: ($a.a + $b.a), e: ($a.e + $b.e), by: ($a.by + $b.by),
     u: ($a.u + $b.u),
     st: addmap($a.st; $b.st), nf: (addmap($a.nf; $b.nf) | top(200)),
     pg: (addmap($a.pg; $b.pg) | top(200)), rf: (addmap($a.rf; $b.rf) | top(200)),
     ag: addmap($a.ag; $b.ag), rc: addmap($a.rc; $b.rc),
     lt: addmap($a.lt; $b.lt)} end;
def merge: {from: (map(.from) | map(select(. != null)) | min),
    hours: (reduce .[] as $s ({}; reduce ($s.hours | to_entries[]) as $e (.;
        .[$e.key] = mergeh(.[$e.key]; $e.value))))};
'

# Summary of stdin's lines, PIECE_LINES at a time, merged. A piece jq fails on (out of
# memory under MemoryMax) is skipped, so the offset still moves on: otherwise every later
# run would fail on the same lines and traffic.json would stop
summary() {
    local piece
    rm -f "$tmp"/piece.* "$tmp/pieces.json"
    touch "$tmp/pieces.json"
    split -a 4 -l "$PIECE_LINES" - "$tmp/piece."
    for piece in "$tmp"/piece.*; do
        [[ -f "$piece" ]] || continue
        if jq -R -n -c --argjson pair "$PAIR_S" "$SUMMARY" < "$piece" > "$tmp/piece.json"; then
            cat "$tmp/piece.json" >> "$tmp/pieces.json"
        else
            echo "skipped $(wc -l < "$piece") lines: summary failed" >&2
        fi
        rm -f "$piece"
    done
    jq -c -s "$MERGE"' merge' "$tmp/pieces.json"
}

# Summarises FILE's lines from its cached offset on, merged into the cache entry
summarise() {
    local file=$1 key=$2 entry=$CACHE/$2.json off=0 size part
    if [[ "$file" == *.gz ]]; then
        [[ -f "$entry" ]] && return 0
        gzip -dc "$file" | summary > "$tmp/new.json"
        jq -c '{off: -1, sum: .}' "$tmp/new.json" > "$entry"
        return 0
    fi
    size=$(stat -c %s "$file")
    [[ -f "$entry" ]] && off=$(jq -r .off "$entry")
    (( off > size )) && { off=0; rm -f "$entry"; }
    (( off == size )) && return 0
    tail -c +$((off + 1)) "$file" | head -c $((size - off)) > "$tmp/chunk"
    # nginx may be mid-line: leave a partial last line for the next run
    if [[ -n "$(tail -c 1 "$tmp/chunk")" ]]; then
        part=$(tail -n 1 "$tmp/chunk" | wc -c)
        head -c $(($(wc -c < "$tmp/chunk") - part)) "$tmp/chunk" > "$tmp/chunk.full"
        mv "$tmp/chunk.full" "$tmp/chunk"
    fi
    summary < "$tmp/chunk" > "$tmp/new.json"
    if [[ -f "$entry" ]]; then
        jq -c -n --slurpfile old "$entry" --slurpfile new "$tmp/new.json" --argjson off \
            $((off + $(wc -c < "$tmp/chunk"))) \
            "$MERGE"' {off: $off, sum: ([$old[0].sum, $new[0]] | merge)}' > "$entry.new"
    else
        jq -c --argjson off "$(wc -c < "$tmp/chunk")" '{off: $off, sum: .}' "$tmp/new.json" \
            > "$entry.new"
    fi
    mv "$entry.new" "$entry"
}

keys=()
for f in "$LOG" "$LOG".1 "$LOG".*.gz; do
    [[ -f "$f" ]] || continue
    key=$(stat -c %i "$f")
    [[ "$f" == *.gz ]] && key=gz-$key
    summarise "$f" "$key"
    keys+=("$key")
done
for entry in "$CACHE"/*.json; do
    [[ -f "$entry" ]] || continue
    k=$(basename "$entry" .json)
    [[ " ${keys[*]} " == *" $k "* ]] || rm -f "$entry"
done

if (( ${#keys[@]} )); then
    entries=()
    for k in "${keys[@]}"; do entries+=("$CACHE/$k.json"); done
    jq -c -s "$MERGE"' map(.sum) | merge' "${entries[@]}" > "$tmp/all.json"
else
    echo '{"from": null, "hours": {}}' > "$tmp/all.json"
fi

now=$(date +%s)
jq -n -r --slurpfile all "$tmp/all.json" --rawfile tsv "$HOURLY" --argjson now "$now" '
    ($all[0].hours | to_entries | map([(.key | tonumber), .value.h, .value.b, .value.a,
        .value.e, .value.by, .value.u])) as $fresh
    | ($fresh | map(.[0])) as $have
    | ($tsv | split("\n") | map(select(length > 0) | split("\t") | map(tonumber))
        | map(select(.[0] as $h | $have | index($h) | not))) + $fresh
    | map(select(.[0] >= $now - 90 * 86400)) | sort_by(.[0])[] | map(tostring) | join("\t")
' > "$tmp/hourly.tsv"
mv "$tmp/hourly.tsv" "$HOURLY"

jq -n -c --slurpfile all "$tmp/all.json" --rawfile tsv "$HOURLY" --argjson now "$now" '
    def addmap($a; $b): reduce ($b | to_entries[]) as $e ($a // {}; .[$e.key] += $e.value);
    def since($s): [$all[0].hours | to_entries[] | select((.key | tonumber) >= $s) | .value];
    def sum($hs; f): reduce ($hs[] | f) as $m ({}; addmap(.; $m));
    def rows($n): to_entries | sort_by(-.value) | .[:$n] | map([.key, .value]);
    def pct($hist; $p): ($hist | to_entries | map([(.key | tonumber), .value]) | sort_by(.[0])) as $b
        | ($b | map(.[1]) | add // 0) as $n
        | if $n == 0 then null
          else first(foreach $b[] as $x (0; . + $x[1]; if . >= $p * $n then $x[0] else empty end))
          end;
    (($now / 3600 | floor) * 3600 - 23 * 3600) as $day
    | (($now / 3600 | floor) * 3600 - (7 * 24 - 1) * 3600) as $week
    | since($day) as $d | since($week) as $w
    | sum($d; .lt) as $lt
    | {
        generated: $now,
        from: $all[0].from,
        hours: ($tsv | split("\n") | map(select(length > 0) | split("\t") | map(tonumber))),
        top_pages: {"24h": (sum($d; .pg) | rows(30)), "7d": (sum($w; .pg) | rows(30))},
        referrers: {"7d": (sum($w; .rf) | rows(20))},
        status: {"24h": (sum($d; .st) | to_entries | sort_by(.key) | map([(.key | tonumber), .value]))},
        not_found: {"24h": (sum($d; .nf) | rows(20))},
        render_cache: {"24h": (sum($d; .rc) | rows(10))},
        latency_ms: {"24h": {p50: pct($lt; 0.5), p95: pct($lt; 0.95), p99: pct($lt; 0.99)}},
        agents: {"7d": (sum($w; .ag) | rows(30))}
      }
' > "$tmp/traffic.json"
install -m 644 "$tmp/traffic.json" "$OUT.tmp"
mv -f "$OUT.tmp" "$OUT"
