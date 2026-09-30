# Setup and auth

## Current setup

| Piece | Value |
| --- | --- |
| Calendar | "Rodina Konrády", owned by tomaskonrady@gmail.com |
| Google Cloud project | `temposheets` (gcloud configuration `personal`) |
| Service account | `kids-calendar@temposheets.iam.gserviceaccount.com`, shared on the calendar with **Make changes to events** |
| Key | `~/dotfiles/family-calendar/.config/family-calendar/gcal-service-account.json` (gitignored stow package), stowed to `~/.config/family-calendar/` |
| `FAMILY_GCAL_CREDENTIALS` | `/Users/tommmyy/.config/family-calendar/gcal-service-account.json` |
| `FAMILY_GCAL_CALENDAR_ID` | `2jvuj5onh6p804iphiucd5a6jo@group.calendar.google.com` |

Both env vars are plain `export NAME="value"` lines in
`~/dotfiles/zsh/.zsh_secrets`, because background jobs grep them out rather
than sourcing that zsh-only file.

## Errors

- `404 (calendar not shared ...)`: the calendar isn't shared with the
  service account, or the calendar ID is wrong.
- `403 ... requiredAccessLevel`: it is shared with read-only access. Change
  it to **Make changes to events**.
- `Google token request failed: invalid_grant` or `Invalid JWT Signature`:
  the key was revoked or deleted. Create a new one:
  `CLOUDSDK_ACTIVE_CONFIG_NAME=personal gcloud iam service-accounts keys create <path> --iam-account=kids-calendar@temposheets.iam.gserviceaccount.com --project=temposheets`
  (with `umask 077`), and delete the old key in the console.

## Rebuilding from scratch

1. Pick a personal Google Cloud project. No billing is needed. Avoid work
   projects: their organizations often forbid service-account keys, and the
   projects disappear with the job.
2. `gcloud services enable calendar-json.googleapis.com --project=<p>`
3. `gcloud iam service-accounts create kids-calendar --project=<p>`, then
   create the key as above into
   `~/dotfiles/family-calendar/.config/family-calendar/`, then
   `stow family-calendar`.
4. In Google Calendar, go to Rodina Konrády → Settings and sharing → Share
   with specific people. Add the service-account email with **Make changes to
   events**. The **Calendar ID** is under Integrate calendar.
5. Set both env vars, then run `node cal.mjs list`.
