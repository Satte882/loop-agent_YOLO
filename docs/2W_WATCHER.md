# 2W Watcher

## Zweck

Der 2W Watcher ist der fehlende lokale Rückkanal zwischen einem abgeschlossenen 2W-Workflow-Lauf und dem nächsten Arbeitsblock.

Der bisherige 2W-Kern ist bewiesen: Ein GitHub Issue mit `2W_READY:` oder `2w:ready` startet GitHub Actions, der self-hosted Runner ruft lokal `codex exec` auf, Codex setzt den Arbeitsblock um, der Workflow committet und kommentiert `2W_DONE`.

Was dadurch noch nicht automatisch passiert: Nach `2W_DONE` wird kein ChatGPT-Fenster geweckt und kein nächster Arbeitsblock erzeugt. Der Watcher schließt genau diese Lücke lokal, ohne OpenAI API-Key, ohne Web-App, ohne Datenbank und ohne Remote-Service.

## Kurzdefinition

Der 2W Watcher ist ein kleines lokales PowerShell-Skript, das regelmäßig GitHub Issues im Zielrepo prüft, neue `2w:done`-Ergebnisse erkennt, Commit und Diff lädt, lokal Codex CLI als Reviewer aufruft und danach entweder ein neues `2W_READY:`-Issue erstellt oder das Ziel als abgeschlossen markiert.

## Warum der Watcher nötig ist

Das aktuelle ChatGPT-Fenster kann nicht direkt durch GitHub Actions aktiviert werden. GitHub kann Issue-Kommentare, Commits und Labels erzeugen, aber nicht dieses Gespräch automatisch fortsetzen.

Ohne Watcher bleibt der Nutzer Teil des Kreislaufs: Er muss nach `2W_DONE` manuell sagen, dass ChatGPT das Issue prüfen soll. Das widerspricht dem eigentlichen Ziel von 2W: Nach der Zieldefinition soll der Nutzer nicht mehr als manueller Bote zwischen ChatGPT, GitHub und Codex CLI gebraucht werden.

Der Watcher übernimmt deshalb die lokale Callback-Rolle.

## Abgrenzung zu einer Engine

Der Watcher ist keine neue Plattform und kein Operator-System.

Er ersetzt nicht den bestehenden 2W-Workflow. Er ergänzt nur den Rückfluss nach einem abgeschlossenen Lauf.

Nicht gemeint sind:

- kein OperatorLoop
- keine DecisionEngine
- keine Datenbank
- keine Web-App
- kein Server
- kein Remote-Daemon
- kein Browser-Control
- keine PR-Orchestrierung
- keine 0Admin-Produktlogik
- keine Multi-Agenten-Plattform
- keine eigene Zustandsmaschine mit komplexer Historie

Gemeint ist ein bewusst kleines lokales Skript mit klarer Aufgabe:

- GitHub prüfen
- Ergebnisdaten einsammeln
- lokale Codex CLI als Reviewer aufrufen
- nächstes Issue erstellen oder Abschluss markieren
- Dedupe-Marker setzen

## Grundprinzipien

## Lokal zuerst

Der Watcher läuft auf dem Rechner des Nutzers. Er nutzt lokale Tools und lokale Authentifizierung.

## Kein API-Key im Standardpfad

Der Watcher nutzt keinen `OPENAI_API_KEY` und keine Cloud-Reviewer-Action. Die Prüfung erfolgt über die lokal installierte Codex CLI, die bereits mit dem gewünschten Nutzerkonto angemeldet ist.

## GitHub bleibt Wahrheitsquelle

GitHub Issues, Labels, Kommentare, Commits und Diffs bleiben die belegbare Quelle. Der Watcher speichert keine eigene Datenbank.

## Dedupe vor Automatisierung

Ein erledigtes Issue darf nicht mehrfach reviewt werden. Der Watcher setzt dafür einen klaren Marker, zum Beispiel `2w:reviewed`.

## Kleine Schritte

Der Watcher erzeugt nur den nächsten kleinen Arbeitsblock. Er soll keine großen, mehrdeutigen Zielpakete auf einmal erzeugen.

## Fail-closed

Wenn Commit-SHA, Diff, Issue-Kommentar oder Codex-Reviewer-Antwort nicht eindeutig sind, erstellt der Watcher kein neues Umsetzungs-Issue. Stattdessen kommentiert er oder markiert das Issue als blockiert.

## Aufgaben des Watchers

## 1. Zielrepo prüfen

Der Watcher prüft ein konfiguriertes GitHub-Repository, zunächst `Satte882/loop-agent_YOLO`.

Er sucht nach offenen Issues mit Label `2w:done`, die noch nicht als `2w:reviewed` markiert sind.

## 2. Ergebnisdaten laden

Für jedes gefundene Issue lädt der Watcher:

- Issue-Nummer
- Issue-Titel
- Issue-Body
- Labels
- Kommentare
- `2W_DONE`-Kommentar
- Commit-SHA aus dem `2W_DONE`-Kommentar
- Commit-Metadaten
- Diff oder Patch
- geänderte Dateien
- Teststatus aus dem Kommentar
- Codex-Exit-Code aus dem Kommentar

## 3. Ergebnis validieren

Der Watcher prüft vor dem Reviewer-Aufruf:

- Gibt es genau einen relevanten `2W_DONE`-Kommentar?
- Gibt es keinen aktuellen `2W_FAILED`-Kommentar nach dem letzten `2W_DONE`?
- Gibt es eine Commit-SHA?
- Ist die Commit-SHA abrufbar?
- Passt der Commit zum Issue?
- Sind die geänderten Dateien im erlaubten Rahmen?
- Ist das Issue noch nicht `2w:reviewed`?

Wenn diese Prüfungen fehlschlagen, wird kein Folge-Issue erstellt.

## 4. Lokale Codex CLI als Reviewer aufrufen

Der Watcher erstellt aus Issue, Kommentar, Commit und Diff einen kompakten Reviewer-Prompt und ruft lokal `codex exec` auf.

Der Reviewer soll entscheiden:

- `NEXT_ISSUE`: Es soll ein weiterer Arbeitsblock erstellt werden.
- `COMPLETE`: Das Ziel ist erfüllt.
- `FIX_ISSUE`: Es soll ein gezielter Fix-Block erstellt werden.
- `BLOCKED`: Der Watcher darf nicht fortfahren.

Die Reviewer-Antwort muss maschinenlesbar genug sein, damit der Watcher keine freie Interpretation erraten muss.

## 5. Folge-Issue erstellen

Wenn der Reviewer `NEXT_ISSUE` oder `FIX_ISSUE` liefert, erstellt der Watcher ein neues Issue mit:

- Titel beginnend mit `2W_READY:`
- Label `2w:ready`
- kleinem, begrenztem Arbeitsauftrag
- klaren Grenzen
- klaren Fertigkriterien

## 6. Abschluss markieren

Wenn der Reviewer `COMPLETE` liefert, markiert der Watcher das bearbeitete Issue mit einem Abschlussmarker, zum Beispiel `2w:complete`, und setzt zusätzlich `2w:reviewed`.

## 7. Dedupe-Marker setzen

Nach erfolgreicher Verarbeitung setzt der Watcher `2w:reviewed` auf dem geprüften Issue.

Das verhindert, dass derselbe `2W_DONE`-Kommentar mehrfach zu neuen Issues führt.

## 8. Bericht schreiben

Der Watcher schreibt einen kurzen Kommentar ins geprüfte Issue, zum Beispiel:

- `2W_REVIEWED`
- erkannte Entscheidung
- erzeugtes Folge-Issue oder Abschlussstatus
- Reviewer-Exit-Code
- kurze Begründung

## Was der Watcher nicht tun soll

Der Watcher soll keine manuelle Kontrolle vortäuschen, die nicht existiert.

Er soll nicht:

- Workflow-Dateien eigenständig ändern
- Templates eigenständig ändern
- Runner installieren
- Runner konfigurieren
- GitHub Actions Workflows reparieren
- Secrets anzeigen oder speichern
- API-Keys verlangen
- OpenAI API aufrufen
- Browser oder ChatGPT-Weboberfläche automatisieren
- eigene Datenbank führen
- Branches oder Pull Requests erstellen
- große Multi-File-Aufgaben ohne klare Grenzen erzeugen
- mehrere Folge-Issues parallel erzeugen
- geschlossene oder bereits reviewte Issues erneut verarbeiten
- Issues mit `2w:failed` automatisch ignorieren oder reparieren, ohne klare Reviewer-Entscheidung
- den bestehenden 2W-Workflow ersetzen

## Minimaler Zustand für v1

Für v1 reicht ein einzelnes PowerShell-Skript:

`scripts/2w-watcher.ps1`

Minimaler Funktionsumfang:

- Parameter für Repository, Poll-Intervall und optionalen One-Shot-Modus
- Prüfung von `gh auth status`
- Prüfung von `codex --version`
- Suche nach Issues mit `2w:done` ohne `2w:reviewed`
- Laden von Issue-Kommentaren
- Extraktion der Commit-SHA aus `2W_DONE`
- Laden des Commits und Diffs über `gh api`
- Aufruf von `codex exec` als Reviewer
- Erzeugen eines Folge-Issues bei eindeutiger Entscheidung
- Setzen von `2w:reviewed`
- Ausgabe eines klaren Terminalberichts

## Betriebsarten

## One-shot

Der Watcher läuft einmal, verarbeitet höchstens ein offenes `2w:done`-Issue und beendet sich.

Diese Betriebsart ist die erste Teststufe.

## Polling

Der Watcher läuft lokal in einer Schleife und prüft alle paar Sekunden oder Minuten auf neue `2w:done`-Issues.

Diese Betriebsart ist der spätere Zielzustand für den autonomen lokalen Loop.

## Task Scheduler

Wenn der One-shot- und Polling-Modus stabil sind, kann der Watcher später über den Windows Task Scheduler gestartet werden.

Das ist optional und nicht Teil der ersten Umsetzung.

## Sicherheitsgrenzen

Der Watcher darf keine Secrets ausgeben.

Der Watcher darf keine Tokens loggen.

Der Watcher darf keine fremden Repositories verarbeiten, sofern sie nicht explizit als Zielrepo übergeben wurden.

Der Watcher darf keine Folge-Issues erzeugen, wenn der Reviewer keine eindeutige Entscheidung liefert.

Der Watcher darf nicht versuchen, unklare Ergebnisse kreativ zu interpretieren.

## Erwartete Labels

- `2w:ready`: Arbeitsblock darf vom 2W-Workflow verarbeitet werden.
- `2w:running`: Arbeitsblock läuft gerade.
- `2w:done`: Arbeitsblock wurde erfolgreich umgesetzt.
- `2w:failed`: Arbeitsblock ist fehlgeschlagen.
- `2w:reviewed`: Watcher hat das Ergebnis verarbeitet.
- `2w:complete`: Ziel wurde als abgeschlossen bewertet.

## Erfolgskriterium für den ersten Watcher-Test

Ein erster Watcher-Test gilt als erfolgreich, wenn:

- ein bestehendes `2w:done`-Issue ohne `2w:reviewed` gefunden wird
- Commit-SHA und Diff korrekt gelesen werden
- Codex CLI als Reviewer lokal gestartet wird
- der Watcher entweder ein neues `2W_READY:`-Issue erstellt oder `2w:complete` setzt
- das geprüfte Issue mit `2w:reviewed` markiert wird
- kein bereits reviewtes Issue erneut verarbeitet wird

## Bewusste Grenze

Der Watcher macht 2W nicht zu einem vollwertigen Agentensystem. Er schließt nur den Callback-Loop zwischen Ergebnis und nächstem Arbeitsblock.

Wenn später komplexere Ziele, Priorisierung, Budgets, Risikostufen oder mehrstufige Strategien nötig werden, muss das gesondert entschieden werden. Für v1 bleibt der Watcher klein, lokal und begrenzt.

## Nutzung v1

Voraussetzungen:

- `gh` ist lokal installiert und angemeldet
- `codex` ist lokal installiert und angemeldet
- kein `OPENAI_API_KEY` ist erforderlich

One-shot:

```powershell
.\scripts\2w-watcher.ps1 -Repo "Satte882/loop-agent_YOLO" -Mode OneShot
```

DryRun:

```powershell
.\scripts\2w-watcher.ps1 -Repo "Satte882/loop-agent_YOLO" -Mode OneShot -DryRun
```

Polling:

```powershell
.\scripts\2w-watcher.ps1 -Repo "Satte882/loop-agent_YOLO" -Mode Poll -IntervalSeconds 60
```

Beenden des Watchers (Poll-Modus):

```powershell
.\scripts\stop-watcher.ps1
```

Hinweise:

- `2w:reviewed` ist der Dedupe-Marker für bereits verarbeitete Issues.
- `2w:done` ist der Eingangspunkt für den lokalen Callback-Loop nach `2W_DONE`.
- `-DryRun` schreibt keine Issues, Labels oder Kommentare.
