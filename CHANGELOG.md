# Changelog

All notable changes to the BaumAgent Clients project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
