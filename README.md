# loop-agent_YOLO

`loop-agent_YOLO` ist ein portables 2W-Starterkit für eine einfache ChatGPT ↔ GitHub Issues ↔ lokale Codex-CLI-Rückkopplung — jetzt im dedizierten YOLO-Modus-Repo.

## Aktueller Validierungsstand

Stand: GitHub-/Cline-ready mit 95 %, End-to-End-bewiesen mit 0 %.

Letzter validierter Stand: `834722ab5a5696e507608428d430b6ed63b1c969`.

Die lokale Cline-Validierung meldete GREEN: lokaler `main` ist mit `origin/main` synchron, Pflichtdateien sind vorhanden, `CI Smoke` ist plausibel, Runtime-Dateien sind API-Key-frei, `actions/checkout@v4` ist gesetzt, Shell-Titelbehandlung ist abgesichert und `changed_files` erfasst auch neue Dateien.

Noch nicht bewiesen ist der echte self-hosted Runner-Pfad: Runner-Registrierung, `codex` im Runner-PATH, `codex --version`, nicht-interaktives `codex exec` und ein erstes `2W_READY:`-Test-Issue.

## Zielbild

Der Nutzer definiert mit ChatGPT ein Ziel und einen kleinen Arbeitsblock. ChatGPT schreibt diesen Arbeitsblock als GitHub Issue in das jeweilige Zielrepo. Das Issue wird durch `2W_READY:` im Titel oder das Label `2w:ready` startfähig. Ein lokaler self-hosted GitHub Actions Runner erkennt das startfähige Issue, ruft im Zielrepo die lokal installierte Codex CLI mit `codex exec` auf und übergibt den Issue-Inhalt als Arbeitsauftrag.

Codex bearbeitet den Arbeitsblock im Repository. Nach der Bearbeitung führt der Workflow verfügbare Checks aus. Wenn der Lauf erfolgreich ist, committet und pusht der Workflow die Änderung direkt in das Zielrepo. Danach kommentiert der Workflow das Issue mit Commit-SHA, Teststatus und geänderten Dateien.

ChatGPT liest anschließend den Issue-Kommentar, den Commit und den Diff über GitHub, bewertet das Ergebnis und entscheidet den nächsten Schritt: fertig, Fix-Block oder Folge-Arbeitsblock. Der nächste Block wird wieder als GitHub Issue erzeugt und startet denselben Ablauf. Ziel ist ein einfacher Arbeitskreislauf, bei dem der Nutzer nach der Zieldefinition nicht mehr als manueller Bote zwischen ChatGPT, GitHub und Codex CLI gebraucht wird.

## Ablauf

1. Nutzer und ChatGPT definieren Ziel und Arbeitsblock.
2. ChatGPT erstellt ein GitHub Issue im Zielrepo.
3. Das Issue ist startfähig durch Titelpräfix `2W_READY:` oder Label `2w:ready`.
4. Ein self-hosted GitHub Actions Runner startet den Workflow.
5. Der Workflow ruft lokal `codex exec` auf.
6. Codex setzt den Arbeitsblock im Zielrepo um.
7. Der Workflow führt verfügbare Checks aus.
8. Bei erfolgreichem Lauf committet und pusht der Workflow.
9. Der Workflow kommentiert das Issue mit Ergebnisdaten.
10. ChatGPT prüft Commit, Diff und Issue-Kommentar über GitHub.
11. ChatGPT erstellt bei Bedarf den nächsten Issue-Block oder einen Fix-Block.

## Aktuelle Nähe zum Zielbild

Der GitHub-seitige Kern ist vorbereitet und validiert: Workflow, Issue-Template, portable Templates, Smoke-CI, Watcher und Dokumentation sind vorhanden. Der Standardpfad nutzt lokale Codex CLI und verlangt keinen `OPENAI_API_KEY`.

Noch nicht bewiesen ist der wichtigste praktische Punkt: Ob `codex exec` im Kontext des self-hosted Runners mit dem lokalen Login ohne interaktive Anmeldung funktioniert. Ebenfalls noch nicht vollständig gelöst ist ein echter automatischer Trigger zurück in dieses offene ChatGPT-Fenster. Der belastbare Rückkanal ist aktuell GitHub: Issue-Kommentar, Commit-SHA und Diff — ergänzt durch den lokalen 2W Watcher.

## Wichtige Entscheidung

Der Standardpfad verwendet keinen `OPENAI_API_KEY` und nicht `openai/codex-action@v1`.

Stattdessen muss Codex CLI lokal auf dem self-hosted Runner verfügbar und bereits mit dem gewünschten Nutzerkonto angemeldet sein. Ob das konkret über ein ChatGPT-Plus-Konto funktioniert, wird lokal validiert. Das Repository erzwingt keinen API-Key.

## Nicht-Ziele

- Kein OperatorLoop.
- Keine eigene Engine.
- Keine Stage-Logik.
- Keine DecisionEngine.
- Kein PR-Workflow.
- Kein Remote-Server.
- Keine 0Admin-Produktlogik.

## Quickstart (5 Minuten)

```powershell
# 1. Repository klonen
git clone https://github.com/Satte882/loop-agent_YOLO.git
cd loop-agent_YOLO

# 2. Voraussetzungen prüfen
.\scripts\2w-watcher.ps1 -Repo "Satte882/loop-agent_YOLO" -Mode OneShot -DryRun

# 3. Watcher im Poll-Modus starten (eigenes Terminal)
.\scripts\start-watcher.ps1 -Repo "Satte882/loop-agent_YOLO"

# 4. Watcher beenden
.\scripts\stop-watcher.ps1
```

Weitere Details in `docs/LOCAL_SETUP.md` und `docs/2W_WATCHER.md`.

## Kern-Dateien

| Datei | Zweck |
|---|---|
| `.github/workflows/2w-codex.yml` | Lokaler 2W-Workflow für dieses Repo |
| `.github/workflows/ci.yml` | Smoke-CI für Repo-Struktur und Runtime-Invarianten |
| `.github/ISSUE_TEMPLATE/2w-workblock.yml` | Issue-Vorlage für 2W-Arbeitsblöcke |
| `templates/2w-local-codex.yml` | Portabler Workflow für andere Repos |
| `templates/ISSUE_TEMPLATE/2w-workblock.yml` | Portables Issue-Template für andere Repos |
| `scripts/2w-watcher.ps1` | Lokaler Callback-Loop nach `2W_DONE` |
| `scripts/start-watcher.ps1` | Watcher-Starthelfer (Task-Scheduler-kompatibel) |
| `scripts/stop-watcher.ps1` | Watcher-Stophelfer |
| `docs/INSTALL_IN_TARGET_REPO.md` | Installation in beliebigen Zielrepos |
| `docs/AUTH_WITH_CHATGPT_PLUS.md` | Authentifizierungsmodell ohne API-Key im Standardpfad |
| `docs/VALIDATE_CODEX_CLI_LOGIN.md` | Lokale Login-/CLI-Validierung |
| `docs/2W_PROTOCOL.md` | Minimaler Kommunikationsvertrag |
| `docs/LOCAL_SETUP.md` | Lokale Einrichtung des self-hosted Runners |
| `docs/VALIDATION.md` | Cline-Validierung nach lokalem `fetch` |
| `docs/SECURITY.md` | Sicherheitsgrenzen für 2W v0 |

## Betriebsmodell

Die GitHub-Historie ist die Wahrheitsquelle. Das ChatGPT-Fenster ist ein Planungs- und Prüfkanal. Lange Logs, vollständige Diffs und sensible Inhalte gehören nicht in den Chat.

`scripts/2w-watcher.ps1` ist der lokale Callback-Loop nach `2W_DONE`.

## 2W v0 in einem Satz

ChatGPT erzeugt ein startfähiges GitHub Issue, der lokale self-hosted Runner führt `codex exec` aus, der Workflow committet und kommentiert, ChatGPT prüft GitHub und startet den nächsten Block.

## Harte Grenzen

Dieses Repo kann keine lokale Codex-Anmeldung durchführen, keinen self-hosted Runner registrieren und nicht garantieren, dass ein ChatGPT-Plus-Login mit der installierten Codex CLI auf Ihrem Rechner funktioniert. Genau dafür gibt es `docs/VALIDATE_CODEX_CLI_LOGIN.md`.