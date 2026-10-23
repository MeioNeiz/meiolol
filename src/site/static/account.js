// Log in, sign up and invite forms (src/site/account.zig) against /auth/ (src/api/accounts.zig).
// The link's token stays in the URL fragment, which browsers never send to a server.
"use strict";
(() => {
  const form = document.getElementById("auth");
  const msg = document.getElementById("auth-msg");
  const kind = form.dataset.kind;
  const token = location.hash.slice(1);

  // Back where nginx sent them from: a path on this site only
  function next(account) {
    const n = new URLSearchParams(location.search).get("next");
    if (n && n.startsWith("/") && !n.startsWith("//")) return n;
    return account.can.includes("view_admin") ? "/admin/" : "/";
  }

  function say(text) {
    msg.textContent = text;
    msg.hidden = false;
  }

  if (kind !== "login" && !token) say("This page needs the link you were sent.");

  form.addEventListener("submit", async ev => {
    ev.preventDefault();
    const f = new FormData(form);
    const body = kind === "login" ? { username: f.get("username").trim(), password: f.get("password") }
      : kind === "signup" ? { link: token, email: f.get("email").trim(), password: f.get("password") }
      : { invite: token, username: f.get("username").trim(), password: f.get("password") };
    const button = form.querySelector("button");
    button.disabled = true;
    msg.hidden = true;
    try {
      const r = await fetch("/auth/" + kind, {
        method: "POST", headers: { "X-Meiolol-Action": "1", "Content-Type": "application/json" },
        body: JSON.stringify(body), credentials: "same-origin", cache: "no-store",
      });
      const j = await r.json().catch(() => ({}));
      if (r.ok) return location.assign(next(j));
      if (r.status === 429) say(`Too many tries: wait ${Math.ceil((j.retry_s || 60) / 60)} min.`);
      else say(j.error ? j.error.charAt(0).toUpperCase() + j.error.slice(1) + "." : `Something went wrong (${r.status}).`);
    } catch {
      say("Can't reach the server. Try again in a moment.");
    }
    button.disabled = false;
  });
})();
