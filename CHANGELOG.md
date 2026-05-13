# Changelog

## v0.2.0 (YOLO Edition) — 2026-05-13

### Verbesserungen

- **Repo-Referenzen aktualisiert** – Alle Verweise von `loop-agent` → `loop-agent_YOLO` in README, Docs und Watcher-Konfiguration. Remote-URL zeigt auf `https://github.com/Satte882/loop-agent_YOLO.git`.

- **Watcher gehärtet** – `scripts/2w-watcher.ps1` um folgende Features erweitert:
  - **Journal-System** – Zeitgestempelte Logs in `.2w/watcher.journal` mit automatischer Rotation ab 500 Zeilen.
  - **Lock-Mechanismus** – PID-basierte Lock-Datei in `.2w/watcher.lock` verhindert parallele Watcher-Instanzen. Stale-Locks werden automatisch erkannt und bereinigt.
  - **Timeout für `codex exec`** – Neuer Parameter `-CodexTimeoutSeconds` (Default: 300s). Überschreitet Codex diese Zeit, wird der Prozess gekillt.
  - **Health-Check** – `Test-Health` prüft vor dem Poll-Loop: `gh auth status`, `codex --version`, GitHub API-Zugriff und (optional) Existenz aller 2W-Labels.
  - **`-SkipHealthCheck`** – Überspringt den Health-Check für schnelle manuelle Tests.

- **Start/Stop-Helfer** – Zwei neue Skripte:
  - `scripts/start-watcher.ps1` – Task-Scheduler-kompatibler Starter mit optionalem Log-File.
  - `scripts/stop-watcher.ps1` – Beendet den Watcher via Lock-Datei oder Prozess-Suche.

- **README überarbeitet** – 5-Minuten-Quickstart, aktualisierte Kern-Dateien-Tabelle, Referenzen auf neue Helfer-Skripte.

### Neu

- `CHANGELOG.md` – Diese Datei.

## v0.1.0 — Initialer 2W-Prototyp

- 2W-Workflow (`2w-codex.yml`) mit lokalem self-hosted Runner
- CI Smoke-Checks (`ci.yml`)
- Issue-Template für 2W-Arbeitsblöcke
- Portable Templates für andere Repos
- Dokumentation: Protokoll, Setup, Sicherheit, Validierung, Authentifizierung
- Erster Watcher-Prototyp (`2w-watcher.ps1`) mit OneShot- und Poll-Modus