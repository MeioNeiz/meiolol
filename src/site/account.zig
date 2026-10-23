//! Log in, sign up, invite and account pages (docs/plan/accounts.md): forms that
//! static/account.js sends to /auth/ (src/api/accounts.zig). Left out of the sitemap and
//! never indexed

const std = @import("std");
const prose = @import("prose.zig");

const Writer = std.Io.Writer;

pub fn login(w: *Writer, _: prose.Info) Writer.Error!void {
    try w.writeAll(
        \\<div class="prose">
        \\<h1>Log in</h1>
        \\<form id="auth" class="auth-form" data-kind="login">
        \\<label>Email or username<input name="username" autocomplete="username" autocapitalize="none" spellcheck="false" required></label>
        \\<label>Password<input name="password" type="password" autocomplete="current-password" required></label>
        \\<button type="submit" class="primary">Log in</button>
        \\<p id="auth-msg" class="note" role="alert" hidden></p>
        \\</form>
        \\</div>
        \\<script src="account.js" defer></script>
        \\
    );
}

/// Through a sign-up link (/signup#LINK): the password is the link's shared one
pub fn signup(w: *Writer, _: prose.Info) Writer.Error!void {
    try w.writeAll(
        \\<div class="prose">
        \\<h1>Make your account</h1>
        \\<form id="auth" class="auth-form" data-kind="signup">
        \\<label>Email<input name="email" type="email" autocomplete="email" autocapitalize="none" spellcheck="false" required></label>
        \\<label>Password<input name="password" type="password" autocomplete="new-password" placeholder="iykyk" minlength="10" required>
        \\<span class="hint">10 or more characters</span></label>
        \\<button type="submit" class="primary">Make account</button>
        \\<p id="auth-msg" class="note" role="alert" hidden></p>
        \\</form>
        \\<p class="muted">Your email is only your login: nothing is sent to it. See the <a href="privacy.html#accounts">privacy policy</a>.</p>
        \\</div>
        \\<script src="account.js" defer></script>
        \\
    );
}

/// One-use invite or password reset (/join#INVITE); a reset ignores the username
pub fn join(w: *Writer, _: prose.Info) Writer.Error!void {
    try w.writeAll(
        \\<div class="prose">
        \\<h1>Set up your login</h1>
        \\<form id="auth" class="auth-form" data-kind="join">
        \\<label>Username<input name="username" autocomplete="username" autocapitalize="none" spellcheck="false">
        \\<span class="hint">Leave it empty if this link resets your password</span></label>
        \\<label>Password<input name="password" type="password" autocomplete="new-password" minlength="8" required>
        \\<span class="hint">8 or more characters</span></label>
        \\<button type="submit" class="primary">Save</button>
        \\<p id="auth-msg" class="note" role="alert" hidden></p>
        \\</form>
        \\<p class="muted">See the <a href="privacy.html#accounts">privacy policy</a>.</p>
        \\</div>
        \\<script src="account.js" defer></script>
        \\
    );
}

/// The signed-in account: who, a new password, sign out here or everywhere. account.js
/// fills #me from /auth/me and sends anyone signed out to the login page
pub fn account(w: *Writer, _: prose.Info) Writer.Error!void {
    try w.writeAll(
        \\<div class="prose">
        \\<h1>Your account</h1>
        \\<p id="me" class="muted">Loading…</p>
        \\<h2>Change your password</h2>
        \\<form id="auth" class="auth-form" data-kind="password">
        \\<label>Current password<input name="password" type="password" autocomplete="current-password" required></label>
        \\<label>New password<input name="new" type="password" autocomplete="new-password" minlength="8" required>
        \\<span class="hint">8 or more characters. Your other devices are signed out</span></label>
        \\<button type="submit" class="primary">Change password</button>
        \\<p id="auth-msg" class="note" role="alert" hidden></p>
        \\</form>
        \\<h2>Sign out</h2>
        \\<p class="auth-out"><button type="button" data-out="">Log out</button>
        \\<button type="button" data-out="all">Log out everywhere</button></p>
        \\<p class="muted">See the <a href="privacy.html#accounts">privacy policy</a>.</p>
        \\</div>
        \\<script src="account.js" defer></script>
        \\
    );
}
