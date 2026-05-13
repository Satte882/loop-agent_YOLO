# Troubleshooting

## Watcher startet nicht

| Symptom | Ursache | Lösung |
|---|---|---|
| `gh auth status` failed | GitHub CLI nicht eingeloggt | `gh auth login` ausführen |
| `codex --version` failed | Codex CLI nicht im PATH | `codex` installieren oder PATH prüfen |
| `Lock held by PID X` | Watcher läuft bereits | Mit `.\scripts\stop-watcher.ps1` beenden oder Lock in `.2w/watcher.lock` manuell löschen |
| Health-Check: `Missing labels` | 2W-Labels fehlen im Repo | Labels manuell anlegen: `2w:ready`, `2w:running`, `2w:done`, `2w:failed`, `2w:reviewed`, `2w:complete` |
| `GitHub API access failed` | Repo existiert nicht oder gh nicht berechtigt | `gh repo view Satte882/loop-agent_YOLO` testen |

## Workflow startet nicht

| Symptom | Ursache | Lösung |
|---|---|---|
| Issue erstellt, kein Workflow-Lauf | GitHub Actions deaktiviert | `Settings -> Actions -> General -> Allow all actions` |
| Workflow startet, prepare-Job skipped | Issue hat weder `2W_READY:`-Titel noch `2w:ready`-Label | Titel oder Label korrigieren |
| Workflow startet, `Local Codex CLI` skipped | prepare-Job hat `should_run=false` | Issue ist closed oder bereits `2w:running`/`2w:done` |
| `codex CLI not found` | Codex fehlt auf dem self-hosted Runner PATH | Runner-Prozess neu starten, Codex-Pfad prüfen |
| Workflow hängt ewig | Codex läuft interaktiv (wartet auf Input) | `timeout-minutes: 30` im Workflow setzt Grenze |
| `codex exec` schreibt `BLOCKED` | Codex hält Aufgabe für unsicher oder unmöglich | Prompt anpassen oder Issue konkretisieren |

## Watcher erzeugt kein Folge-Issue

| Symptom | Ursache | Lösung |
|---|---|---|
| `Keine Commit-SHA im letzten 2W_DONE` | Workflow hat `commit=none` gemeldet | Workflow-Logs prüfen, warum kein Commit |
| `Commit konnte nicht geladen werden` | SHA ungültig oder API-Rate-Limit | `gh api rate-limit` prüfen |
| `2w:failed nach letztem 2W_DONE` | Nach erfolgreichem Durchlauf gab es einen Fehler | Workflow-Logs prüfen |
| `Reviewer unreadable` | Codex CLI als Reviewer abgestürzt | Watcher-Journal in `.2w/watcher.journal` prüfen |
| `Reviewer timed out` | Codex hat länger als `-CodexTimeoutSeconds` gebraucht | Timeout erhöhen: `-CodexTimeoutSeconds 600` |
| Issue bleibt `2w:done` ohne `2w:reviewed` | Watcher hat Issue nicht erreicht (Lock, Fehler) | Watcher-Journal prüfen, `-DryRun` testen |

## Journal und Logs lesen

```powershell
# Watcher-Journal anzeigen
Get-Content .2w/watcher.journal

# Nur Fehler anzeigen
Select-String "ERROR|WARN|BLOCKED" .2w/watcher.journal

# Journal überwachen (bei laufendem Watcher)
Get-Content .2w/watcher.journal -Wait
```

## Lock zurücksetzen

Wenn der Watcher abgestürzt ist und die Lock-Datei übrig geblieben ist:

```powershell
# Manuell
Remove-Item .2w/watcher.lock -Force

# Oder per Stop-Skript
.\scripts\stop-watcher.ps1 -Force
```

## Pre-Commit-Hook aktivieren

```powershell
git config core.hooksPath .githooks
```

Dann wird bei jedem `git commit` automatisch die PowerShell-Syntax aller Skripte geprüft.

## Bekannte Grenzen (2W v0)

- **Kein PR-Workflow** – 2W v0 committet direkt auf den Branch.
- **Kein Multi-Repo** – Ein Watcher-Lauf verarbeitet nur ein konfiguriertes Repo.
- **Kein Dashboard** – Status ist nur via GitHub Issues und Watcher-Journal einsehbar.
- **Kein automatischer ChatGPT-Trigger** – Der Rückkanal zu ChatGPT bleibt GitHub (kein API-Key, kein Webhook).
- **Self-hosted Runner nötig** – Ohne Runner kein Workflow-Start.