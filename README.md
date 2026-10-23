# Supplement Tracker — GitHub Pages + Supabase migration candidate

Retains V4.2 Midnight Blue Today, Analysis, History, Library, routines, favorites, label-verified supplement definitions and frozen historical snapshots. This is a **migration candidate**, not a deployed or end-to-end browser-tested release.

## Key changes
- Frontend `index.html` is static; `/api/state` requests were replaced by a Supabase authenticated read and revision-checked atomic write.
- Supabase Auth email/password login; row-level access controlled by `auth.uid()`.
- Existing logs/snapshots retained as a whole JSON document. Writes reject stale revisions instead of silently overwriting changes.
- Existing in-app JSON backup restore can import exported Synology SQLite state.
- **XLSX import via Python is not available**; convert Excel to CSV before import. CSV and paste-text import remain in the browser.
- Does **not** provide offline writes or native iOS synchronization yet. Concurrent browser edit conflicts are detected, not merged.
- On new accounts V4.2 seeded product definitions display, but no database record is created until a save/import.

## Setup
1. Create a **Supabase project**, open `SQL Editor`, run `supabase/schema.sql`.
2. In Supabase Authentication > Users, create/verify your **one user**. Disable public sign-ups under Auth settings. Configure the site URL to the eventual GitHub Pages HTTPS URL. Consider enabling MFA.
3. Copy your Supabase **Project URL** and **publishable / anon public key** from API settings into `config.js`. These values are intentionally public, secured by RLS. **NEVER put `service_role` or secret keys in frontend code.**
4. Create a GitHub repo `supplement-tracker`; for **GitHub Free Pages, it must be public**. Pages publishes publicly even if a paid plan lets you use private repo sources. Do not commit personal databases/JSON backups.
5. Add the files from this folder to the repository root. In repo Settings > Pages, choose Deploy from branch `main` / `(root)`; wait for HTTPS URL.
6. Sign in to the GitHub Pages app with your Supabase account. Verify state starts empty/new before data migration.

## Export your Synology data safely
Make a consistent live SQLite backup on NAS using Python's SQLite backup API, **not** copying a database mid-write:

```bash
cd /volume1/docker/NutrientTracker
sudo docker compose ps
# First locate the mounted data path and database; preserve data and do not delete containers.
# If DB is in ./data/ledger.sqlite3, run Python sqlite3.backup from the host with Python installed.
python3 - <<'PYCODE'
import sqlite3
src=sqlite3.connect('data/ledger.sqlite3')
dst=sqlite3.connect('data/ledger-cloud-backup.sqlite3')
src.backup(dst)
dst.close();src.close()
print('Backup created')
PYCODE
```

Then copy `ledger-cloud-backup.sqlite3` to your Mac (e.g. SCP) and use:

```bash
python3 tools/export_sqlite_state.py ledger-cloud-backup.sqlite3 state-backup.json
```

**Do not commit `state-backup.json` to GitHub.** In the GitHub Pages app after signing in, go to Restore Backup and import the JSON. Wait until the status says saved to Supabase, then refresh and check dates, snapshots, nutrients and all 21 products. Preserve your Synology instance until validation is complete.

## Validation checklist
- Login is required; another logged-out browser cannot access personal state.
- There are 21 products (17 active and 4 inactive/discontinued) in the expected V4.2 data set.
- All historical dates and frozen nutrient snapshots are present.
- Log one supplement then reload; the entry persists.
- Restore backup into a clean project only once; repeat restore overwrites cloud state intentionally.
- Verify CSV details/aggregate exports and paste/CSV imports.
- Verify an edit from two tabs triggers a conflict warning, not a silent overwrite.

## Limitations
- Uploading an untrusted SQLite database or backup directly to GitHub is unsafe. Only transfer through your browser after authenticated Supabase setup.
- JSON state document writes are whole-state; future native iOS sync will need normalized data tables and per-record revisions.
- The first restore changes the cloud state; retain the original NAS and a separate backup. Browser JS compatibility and cloud policies must be checked in your environment before cutting over.