// Log in, sign up, invite and account forms (src/site/account.zig) against /auth/
// (src/api/accounts.zig).
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
    return account.can.includes("view_admin") ? "/admin/" : account.can.includes("view_private") ? "/p/" : "/";
  }

  function say(text) {
    msg.textContent = text;
    msg.hidden = false;
  }

  const post = (path, body) => fetch("/auth/" + path, {
    method: "POST", headers: { "X-Meiolol-Action": "1", "Content-Type": "application/json" },
    body: JSON.stringify(body), credentials: "same-origin", cache: "no-store",
  });

  if (kind === "password") {
    const me = document.getElementById("me");
    fetch("/auth/me", { credentials: "same-origin", cache: "no-store" }).then(async r => {
      if (r.status === 401) return location.assign("/login.html?next=/account.html");
      if (!r.ok) throw new Error(r.status);
      const a = await r.json();
      me.replaceChildren(`Logged in as `, Object.assign(document.createElement("b"), { textContent: a.username }), ` (${a.role}).`);
      const links = [["view_private", "/p/", "Draft tester"], ["view_admin", "/admin/", "Admin pages"], ["manage_accounts", "/admin/#accounts", "Accounts"]]
        .filter(([cap]) => a.can.includes(cap));
      for (const [i, [, href, text]] of links.entries()) {
        me.append(i ? " · " : " ", Object.assign(document.createElement("a"), { href, textContent: text }));
      }
    }).catch(() => { me.textContent = "Can't reach the server. Try again in a moment."; });
    for (const b of document.querySelectorAll("[data-out]")) {
      b.addEventListener("click", async () => {
        await fetch("/auth/logout" + (b.dataset.out ? "?all=1" : ""), { method: "POST", headers: { "X-Meiolol-Action": "1" }, credentials: "same-origin" }).catch(() => {});
        location.assign("/login.html");
      });
    }
  } else if (kind !== "login" && !token) say("This page needs the link you were sent.");

  form.addEventListener("submit", async ev => {
    ev.preventDefault();
    const f = new FormData(form);
    const body = kind === "login" ? { username: f.get("username").trim(), password: f.get("password") }
      : kind === "signup" ? { link: token, email: f.get("email").trim(), password: f.get("password") }
      : kind === "password" ? { password: f.get("password"), new: f.get("new") }
      : { invite: token, username: f.get("username").trim(), password: f.get("password") };
    const button = form.querySelector("button");
    button.disabled = true;
    msg.hidden = true;
    try {
      const r = await post(kind, body);
      const j = await r.json().catch(() => ({}));
      if (r.ok && kind === "password") {
        form.reset();
        say("Password changed. Your other devices are signed out.");
      } else if (r.ok) return location.assign(next(j));
      else if (r.status === 401 && kind === "password") return location.assign("/login.html?next=/account.html");
      else if (r.status === 429) say(`Too many tries: wait ${Math.ceil((j.retry_s || 60) / 60)} min.`);
      else say(j.error ? j.error.charAt(0).toUpperCase() + j.error.slice(1) + "." : `Something went wrong (${r.status}).`);
    } catch {
      say("Can't reach the server. Try again in a moment.");
    }
    button.disabled = false;
  });
})();
