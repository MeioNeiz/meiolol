#!/usr/bin/env bash
# deploy/zigstd.sh [GREP-FLAGS] PATTERN [PATH]: grep (-E) the std source of the zig on
# PATH, the pinned 0.17. PATH is under lib/std (`http/Server.zig`, `Io`), and so are the
# printed paths. Flags take their value joined (`-A5`, `-w`). Prints at most ZIGSTD_MAX
# lines (60): a loose pattern over all of std runs to thousands.
# `deploy/zigstd.sh --dir` prints lib/std, for `sed -n` on a file found
set -euo pipefail
std=$(zig env | sed -n 's/^ *\.lib_dir = "\(.*\)",$/\1/p')/std
[[ -d $std ]] || { echo "zigstd: no std at '$std' (zig env changed?)" >&2; exit 2; }
[[ ${1:-} == --dir ]] && { echo "$std"; exit 0; }
flags=()
while [[ ${1:-} == -* ]]; do flags+=("$1"); shift; done
(( $# )) || { echo "usage: deploy/zigstd.sh [grep flags] PATTERN [PATH] | --dir" >&2; exit 2; }
cd "$std"
out=$(grep -rnE --include='*.zig' ${flags[@]+"${flags[@]}"} -- "$1" "${2:-.}" | sed 's|^\./||') || true
[[ -n $out ]] || { echo "zigstd: no match for '$1' in std/${2:-}" >&2; exit 1; }
max=${ZIGSTD_MAX:-60}
n=$(wc -l <<<"$out")
head -n "$max" <<<"$out"
(( n <= max )) || echo "zigstd: $((n - max)) more lines, narrow PATTERN or PATH" >&2
