# YOLO_Verbesserungen.md
# 13.05.2026

---
## 🚀 v0.2.0 YOLO Edition — erfolgreich deployed

Das gesamte Repo wurde bereinigt, gehärtet und auf das neue Repo **https://github.com/Satte882/loop-agent_YOLO** gepusht.

### Was ich verbessert habe, um von ~95% auf >100% zu kommen:

| Problem | Lösung |
|---|---|
| Alle Referenzen zeigen noch auf `loop-agent` | Alle 7 Dateien mit Referenzen auf `loop-agent_YOLO` aktualisiert |
| Watcher kann hängen (kein Timeout) | Neuer Parameter `-CodexTimeoutSeconds` (Default 300s) – Codex wird nach N Sekunden gekillt |
| Watcher startet doppelt (kein Lock) | PID-basierte Lock-Datei in `.2w/watcher.lock`, stale locks werden erkannt |
| Kein Logging/Journal | Zeitgestempeltes Journal in `.2w/watcher.journal` mit Rotation ab 500 Zeilen |
| Keine Vorab-Prüfung vor Poll-Loop | `Test-Health` prüft gh auth, codex version, GitHub API und 2W-Labels |
| Kein Start/Stop-Helfer | `scripts/start-watcher.ps1` (Task-Scheduler-kompatibel) + `scripts/stop-watcher.ps1` (via Lock oder Prozess-Suche) |
| Kein Changelog | `CHANGELOG.md` mit v0.1.0 → v0.2.0 Historie |
| README ohne Quickstart | 5-Minuten-Quickstart mit konkreten PowerShell-Befehlen |

### Nächster logischer Schritt für >100%:
- **Self-hosted Runner registrieren** für dieses Repo
- **Issue #1 erstellen** mit `2W_READY: Testlauf` und sehen ob der Kreislauf lokal durchläuft
- Dann ist der gesamte 2W-Loop: **ChatGPT → Issue → Runner → Codex → Commit → Watcher → nächstes Issue** bewiesen


---

## 🚀 Jetzt auf https://github.com/Satte882/loop-agent_YOLO

**v0.2.1** – zwei Commits, alle Verbesserungen live auf GitHub.

### Alle Verbesserungen im Überblick (von ~95% auf >100%):

| Bereich | Was habe ich gemacht |
|---|---|
| **Repo-Referenzen** | `loop-agent` → `loop-agent_YOLO` in 7 Dateien + Remote-URL |
| **Timeout** | `-CodexTimeoutSeconds` (Default 300s) – Codex wird nach N Sekunden gekillt |
| **Lock-Mechanismus** | PID-basierte Lock-Datei `.2w/watcher.lock`, stale locks werden erkannt |
| **Journal** | Zeitgestempeltes Log in `.2w/watcher.journal` mit Rotation ab 500 Zeilen |
| **Health-Check** | `Test-Health` prüft vor dem Poll-Loop: gh auth, codex version, GitHub API, 2W-Labels |
| **Resilienter Poll-Loop** | Fehler in `Invoke-2WWatcherOnce` killen nicht mehr die gesamte Schleife – der Loop läuft weiter |
| **Start/Stop-Helfer** | `scripts/start-watcher.ps1` (Task-Scheduler-kompatibel) + `scripts/stop-watcher.ps1` |
| **CI-Smoke erweitert** | PowerShell-Syntax-Check für alle `scripts/*.ps1` + Existenz-Prüfung neuer Dateien |
| **Pre-Commit-Hook** | `.githooks/pre-commit` prüft PowerShell-Syntax bei jedem `git commit` (aktivieren mit `git config core.hooksPath .githooks`) |
| **Troubleshooting** | `docs/TROUBLESHOOTING.md` mit 15 Symptom/Ursache/Lösung-Tabellen |
| **.2w/README.md** | Dokumentation der Runtime-Artifakte |
| **CHANGELOG** | Versionierte Historie |
| **README** | 5-Minuten-Quickstart |

### Was noch fehlt (aber nur lokal lösbar):
1. **Self-hosted Runner registrieren** für `loop-agent_YOLO`
2. **2W-Labels anlegen** (2w:ready, 2w:running, 2w:done, 2w:failed, 2w:reviewed, 2w:complete)
3. **Issues #1** mit `2W_READY: Testlauf` erstellen und durchlaufen lassen
4. **Pre-Commit-Hook aktivieren**: `git config core.hooksPath .githooks`

