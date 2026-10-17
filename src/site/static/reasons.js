// Draft model reasons the public pages may name (Daily Draft reveal, Learn practice):
// lane matchups and the role pairings the model detects (docs/learned.md "Win"): mid vs
// bot, bot vs support and top vs mid across the lanes, and among allies bot with
// support. Reasons from any other pairing are noise, so never shown. Words, no points.
"use strict";

const reasonPair = (a, b) => [a, b].sort().join(" ");
const DETECTED_PAIRS = {
  enemy: new Set([
    ...["top", "jungle", "middle", "bottom", "utility"].map((r) => reasonPair(r, r)),
    reasonPair("middle", "bottom"),
    reasonPair("bottom", "utility"),
    reasonPair("top", "middle"),
  ]),
  ally: new Set([reasonPair("bottom", "utility")]),
};

// Reason `r` of a pick in `role` (kind ally or enemy) is a detected pairing
const detectedReason = (role, r) => DETECTED_PAIRS[r.kind]?.has(reasonPair(role, r.role)) ?? false;

// "Tends to do well against Zed", for reason `r` with `other` its champion's name
function reasonWords(r, other) {
  if (r.kind === "enemy") {
    return r.pp > 0 ? `Tends to do well against ${other}` : `Tends to struggle against ${other}`;
  }
  return r.pp > 0 ? `Tends to win more with ${other}` : `Tends to win less with ${other}`;
}
