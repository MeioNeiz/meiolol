# #1181 [BUG] App Request Form (RSO) fails with HTTP 500 Internal Server Error on submit

Opened 2026-08-20T01:35:44Z by tasteofhouse, state open

**Bug Description**
The RSO App Request Form on the beta Developer Portal (beta.developer.riotgames.com) fails to submit, returning HTTP 500 on every attempt, blocking RSO game access requests for approved production applications.

**Problem Description**
After a VALORANT production API key is approved, the Developer Portal sends an invite to request RSO game access via the App Request Form. Submitting this form consistently fails with a server-side 500 error, with no actionable error message returned to the user. This blocks completing the RSO setup required to implement OAuth within the 30-day window following key approval.

Notably, our account already has an existing, approved RSO Client (App ID 740121, granted LoL/TFT/LoR methods only, zero VALORANT methods). Based on the client-side source, this form calls `createRsoClient` (POST /api/xdp/v1/rso-client, intended for creating a brand-new RSO client), rather than adding game access to our existing RSO Client. Since RSO Clients are shared 1-per-account, we suspect this form may be attempting to create a second RSO client for an account that already has one, and the backend may be throwing an unhandled exception on that conflict instead of returning a clear validation error.

**Expected Result**
VALORANT game access is added to our existing RSO Client (App ID 740121), and the app (867270) is granted the requested game access.

**Actual Result**
A generic client-side popup appears: "Oops! An error occurred. Please try again."

Network trace:
- OPTIONS preflight to the RSO client endpoint returns 200.
- The POST request (api/xdp/v1/rso-client, called from rsoClient.thunks.ts:27) returns HTTP 500.
- Response body: `{ "httpStatus": 500, "errorCode": "INTERNAL_SERVER_ERROR" }` — no further detail provided.

Two possible causes identified from the client-side source:
1. A `contactEmail` form field maps to a `contacts` field in the API payload, but there is no Contact Email input anywhere in the visible form UI — it's always sent as an empty array, which may be triggering an unhandled server-side exception if `contacts` is required to be non-empty.
2. The form calls `createRsoClient` (new client creation) instead of adding game access to our existing RSO Client (740121) — see Problem Description above.

**Developer Impact**
* Frequency: Every single submission attempt (100% reproduction rate across multiple attempts, multiple sessions).
* Severity: Completely blocks RSO game access setup for an already-approved production application — cannot proceed with OAuth implementation.
* Cost: Blocks a shipped feature (VALORANT ranked ladder / auto-participate) from launching on schedule, and risks losing the API key if the 30-day OAuth implementation window expires before this is resolved.
* Etc: Independently confirmed by at least one other developer in the Riot Developer Discord (#rso-dev, 2026-08-20) reporting the identical symptom with the App Request Form.

**Player Impact**
* Frequency: Indirect — this blocks a developer-side integration, not a currently-live player-facing feature.
* Severity: Players cannot yet access the VALORANT ranked ladder / auto-participate feature we're building, since RSO setup cannot be completed.
* Region: Affects KR PC-bang (PC café) players once the feature launches.

**Preconditions**
* Have an approved Production API application for VALORANT (App ID 867270).
* Already have an existing, separately-approved RSO Client on the same account (App ID 740121), currently scoped to LoL/TFT/LoR only, with zero VALORANT methods.
* Received the RSO invite link to beta.developer.riotgames.com to request additional game access via the App Request Form.
* Note: the Developer Portal account used here was previously transferred from another user's account (ownership change), rather than being an originally self-registered account — flagging in case stale ownership/account-linkage data is related to this server-side failure.

**Repro Steps**
1. Sign in to beta.developer.riotgames.com with an account that has an approved production VALORANT application, and an existing separate RSO Client already approved for other games.
1. Open the App Request Form for the approved App ID.
1. Fill in Client Name, Client Logo (square PNG within 275x275–60x60), Game Access (VALORANT only), Privacy Policy URL, Terms of Service URL, Redirect URIs, and Post Logout Redirect URIs.
1. Click Submit.

**Issue Comments**
If you're also experiencing this issue, please add your App ID and the exact error/response body you see — this has already been independently reproduced by at least two developers, so additional reports will help demonstrate the scale of impact to prioritize a fix.

