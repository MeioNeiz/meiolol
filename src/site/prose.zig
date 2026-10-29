//! What the account pages (account.zig) take, and the download page's admin script. The
//! text pages themselves: textpages.zig

const std = @import("std");

pub const Info = struct {
    contact: []const u8,
    /// "11 October 2026"
    updated: []const u8,
    /// The shared view's, for Daily Draft: "16.21"
    patch: []const u8 = "",
};

/// Jacob's download before the release: the admin page stores the zip's path and patch in
/// this origin's localStorage (admin.js pollDesktop), as html.zig admin_link; the zip
/// itself stays behind the admin login
pub const admin_download =
    \\<script>try{const d=JSON.parse(localStorage.getItem("admin-desktop"));
    \\if(d&&typeof d.href=="string"&&d.href.startsWith("/admin/")){
    \\const p=document.createElement("p"),a=document.createElement("a");p.className="note";
    \\a.href=d.href;a.download="";a.textContent="Download for Windows";
    \\a.style.cssText="display:inline-block;margin-bottom:6px;padding:7px 16px;border-radius:8px;"
    \\+"background:var(--accent);color:var(--bg);font-weight:600";
    \\p.append(a,document.createElement("br"),`Admin only until the public release. Unzip
    \\ it and run meiolol-desktop.exe in the meiolol folder; Windows asks first (More info,
    \\ then Run anyway). It downloads patch ${d.patch} statistics on first start and keeps
    \\ them and itself up to date.`);
    \\document.getElementById("admin-download").append(p)}}catch(e){}</script>
    \\
;
