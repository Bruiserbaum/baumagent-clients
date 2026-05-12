# Changelog

All notable changes to the BaumAgent Clients project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.0] — 2025-07-19

### Fixed — Windows client

- **"Server returned an HTML page instead of JSON" error on Settings / History.**
  The HTML-body sniff in `ReadJsonAsync` now runs *before*
  `EnsureSuccessStatusCode()` so that Authentik forward-auth redirects
  (which return a 200 OK with an HTML login page) are caught and produce a
  clear, actionable message instead of a JSON-parse exception.  The error
  message itself has been improved: it now explicitly tells the user their
  session or token may have expired and directs them to re-pair.
- **API Tokens card now shows a contextual "Re-pair device" button** when the
  token-list load fails with an auth-related error (HTML page, 401, 403).
  Previously the user had to scroll down to the Danger Zone to find the
  Re-pair button.
- **History page error colour** — when `LoadAsync` fails the `StatusText`
  label now turns red (`BaumDangerBrush`) so the error is visually
  distinguishable from a normal loading state.
- **Danger Zone section** — the "Account" heading in the danger-zone card was
  easily confused with the top "Account" info card.  It has been renamed to
  "⚠ Danger Zone" with a warning icon so its destructive intent is obvious.

### Added — Windows client

- **Git Nexus — Indexed Repositories settings card.**  A new card on the
  Settings page fetches `GET /api/gitnexus/repos` and displays all
  repositories tracked by the server's Git Nexus indexing subsystem.  For
  each repo the card shows:
  - Owner/repo path (e.g. `Bruiserbaum/baumagent-clients`)
  - Default branch and indexed file count
  - Last-indexed timestamp
  - Colour-coded **Index status** badge (`Indexed` / `Indexing…` / `Pending`
    / `Error` / `Not indexed`)
  - Colour-coded **Pull status** badge (`Up to date` / `Pulling…` / `Pull error`)
  - A **Refresh** button to re-query the server at any time
  If the endpoint is unavailable (e.g. Nexus not configured on the server) an
  error message is shown non-fatally; the rest of the Settings page still
  loads normally.

### Added — API client (`BaumAgentApiClient`)

- `ListNexusReposAsync()` — `GET /api/gitnexus/repos`
- `TriggerNexusReindexAsync(repoId)` — `POST /api/gitnexus/repos/{id}/reindex`
- `TriggerNexusPullAsync(repoId)` — `POST /api/gitnexus/repos/{id}/pull`

### Added — Models

- `NexusRepo` record with computed display helpers (`ShortName`, `OwnerRepo`,
  `IndexStatusLabel`, `PullStatusLabel`, `LastIndexedDisplay`, `FileCountDisplay`).

### Added — OpenAPI spec

- `GitNexusRepo` schema (index status, pull status, timestamps, file count).
- `GitNexusIndexStatus` and `GitNexusPullStatus` enum schemas.
- `GET /api/gitnexus/repos`, `POST /api/gitnexus/repos/{repoId}/reindex`,
  `POST /api/gitnexus/repos/{repoId}/pull` path entries.
- Previously missing path entries for `/api/queue`, `/api/projects`,
  `/api/settings`, `/api/models`, and task sub-resources (`/exports`,
  `/download`) have been added so the spec is complete.

### Changed

- Bumped Windows client version 1.1.0 → 1.2.0 (minor bump for new feature).

---

## [1.1.0] — 2025-07-18

### Fixed — Windows client

- **Task list auto-refresh now updates task statuses in real-time.** Previously,
  the 5-second auto-refresh timer only updated the queue summary counts
  (Queued / Running) but did not reload the actual task list. Tasks that
  transitioned from "queued" to "running" (or to any terminal state) kept
  showing their stale status badge until the user navigated away and back.
  The timer now calls the full `LoadAsync()` method, which refreshes both the
  queue counts and every task row.
- **Added a guard against overlapping refresh loads.** Rapid manual "Refresh"
  clicks or timer re-entry no longer cause duplicate concurrent API calls.
- **Refresh errors are now visible.** A previously silent `catch {}` swallowed
  all load/refresh failures; a red error banner now surfaces the message so
  users know when something is wrong.
- **Smart diff on refresh** avoids rebuilding the entire ListView when the data
  has not changed, preventing UI flicker and scroll-position loss.

### Added — Windows client

- **Project selector** on the Create Task page. Projects are fetched from the
  server's `GET /api/projects` endpoint and displayed in a dropdown. Selecting
  a project passes the `project_id` field to the task creation API.
- **Image paste & file attachment support** on the Create Task page. Users can
  now paste an image from the clipboard (📋 Paste image) or browse for image
  files (📁 Browse…). Attached images are sent as multipart file parts in the
  `POST /api/tasks` request. A thumbnail preview, filename, and file size are
  shown for each attachment, with the ability to remove individual images.
- **Delivery mode selector** for research-type tasks (Research, Deep Research,
  Structured Document). Users can choose between Document (.docx),
  Markdown (.md), and PDF (.pdf) output formats, sent as `delivery_mode` in
  the task creation form.

### Changed

- Bumped Windows client version from 1.0.7 → 1.1.0 (minor bump for new features).
