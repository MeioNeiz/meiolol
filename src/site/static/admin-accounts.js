// meiolol admin dashboard: the Accounts tab (admin.js draws the rest). Logins from /auth/
// (src/api/accounts.zig): the list, invite links, role, disable and reset, on accounts
// below the signed-in role only (the server checks again). The owner and deletion stay
// with `meiolol account` over ssh (docs/hosting.md "Logins").

const ACCOUNTS = { list: null, err: null, link: null, busy: false };

async function loadAccounts() {
  try { ACCOUNTS.list = await getJson("/auth/accounts"); ACCOUNTS.err = null; } catch (e) { ACCOUNTS.err = e.message; }
  if (ui.tab === "accounts") render(true);
}

// POST to /auth/NAME; the answer's JSON, or throws with the server's message
async function accountPost(name, body) {
  const r = await fetch("/auth/" + name, {
    method: "POST", headers: { "X-Meiolol-Action": "1", "Content-Type": "application/json" },
    body: JSON.stringify(body), credentials: "same-origin", cache: "no-store",
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.error || r.status + " " + r.statusText);
  return j;
}

async function accountChange(name, body, link) {
  if (ACCOUNTS.busy) return;
  ACCOUNTS.busy = true;
  try {
    const j = await accountPost(name, body);
    if (j.invite) ACCOUNTS.link = { url: `${location.origin}/join#${j.invite}`, label: link };
    ACCOUNTS.err = null;
  } catch (e) {
    ACCOUNTS.err = e.message;
  }
  ACCOUNTS.busy = false;
  await loadAccounts();
}

function accountsView(body) {
  const sec = section(body, "Accounts", "Logins for the admin pages and the private site. You can change accounts below your own role; the owner, and deleting an account, only with meiolol account over ssh.");
  if (ME && !ME.can.includes("manage_accounts")) {
    sec.append(el("p", { class: "muted" }, "Your role cannot manage accounts."));
    return;
  }
  if (ACCOUNTS.list == null && ACCOUNTS.err == null) {
    loadAccounts();
    sec.append(el("p", { class: "muted" }, "Loading…"));
    return;
  }
  if (ACCOUNTS.err) sec.append(el("div", { class: "health bad" }, el("b", {}, "Accounts: "), ACCOUNTS.err));
  const A = ACCOUNTS.list;
  if (!A) return;

  if (A.roles.length) {
    const roles = A.roles.filter(r => r !== "public");
    const pick = el("select", { "aria-label": "Role" }, ...roles.map(r => el("option", { value: r, selected: r === "private" }, cap(r))));
    sec.append(el("div", { class: "invite" },
      pick,
      el("button", { type: "button", class: "action", onclick: () => accountChange("invite", { role: pick.value }, `New ${pick.value} account`) }, "Make invite link"),
      el("span", { class: "sub" }, "One use, 7 days: they pick a username and password.")));
  }
  if (ACCOUNTS.link) {
    const { url, label } = ACCOUNTS.link;
    const box = el("input", { readonly: true, value: url, "aria-label": label, onfocus: ev => ev.target.select() });
    sec.append(el("div", { class: "health good invite-link" },
      el("b", {}, label + ": "), "send this link by chat. It is shown only now.",
      el("div", { class: "invite" }, box,
        el("button", { type: "button", class: "action", onclick: () => navigator.clipboard.writeText(url) }, "Copy"),
        el("button", { type: "button", class: "ghost", onclick: () => { ACCOUNTS.link = null; render(true); } }, "Done"))));
  }

  const roleCell = (v, a) => {
    if (!a.manage) return cap(v);
    return el("select", {
      "aria-label": `Role of ${a.username}`,
      onchange: ev => {
        if (confirm(`Make ${a.username} ${ev.target.value}?`)) accountChange("role", { username: a.username, role: ev.target.value });
        else ev.target.value = v;
      },
    }, ...A.roles.map(r => el("option", { value: r, selected: r === v }, cap(r))));
  };
  const actions = (_, a) => !a.manage ? "" : el("span", { class: "actions" },
    el("button", {
      type: "button", class: a.disabled ? "action" : "action danger",
      onclick: () => {
        if (a.disabled || confirm(`Disable ${a.username}? It is signed out everywhere and can't log in until enabled.`)) {
          accountChange("disable", { username: a.username, disabled: !a.disabled });
        }
      },
    }, a.disabled ? "Enable" : "Disable"),
    el("button", { type: "button", class: "action", onclick: () => accountChange("reset", { username: a.username }, `Password reset for ${a.username}`) }, "Reset link"));
  const rows = A.accounts.map(a => ({ ...a, status: a.disabled ? "disabled" : "active" }));
  table(sec, "accounts", [
    { key: "username", label: "Login" },
    { key: "role", label: "Role", fmt: roleCell },
    { key: "status", label: "Status", fmt: v => el("span", { class: "pill " + (v === "active" ? "good" : "bad") }, v) },
    { key: "last_seen", label: "Last seen", num: true, fmt: v => v == null ? "never" : ago(v) },
    { key: "created", label: "Made", num: true, fmt: v => dayDate(v) },
    { key: "manage", label: "", fmt: actions },
  ], rows);
}
