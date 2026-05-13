# Greenfield.md

# 13.05.2026

Hier meine ehrliche Einschätzung – getrennt in "wirklich relevant" vs. "nice-to-have":

---

## 💎 Wirklich relevant (ohne diese Dinge bleibt das System fragil)

### 1. E2E-Test / Selbsttest-Mechanismus (K.O.-Kriterium)

Das größte Problem heute: **Niemand weiß, ob der Loop funktioniert, bevor er wirklich läuft.**

- Wenn ich grünes Licht hätte, würde ich einen "Selbsttest-Modus" bauen: Der Watcher erstellt ein `2W_READY: self-test`-Issue, wartet auf `2W_DONE`, validiert den Commit und löscht ihn wieder.
- Ohne diesen Test ist jede Änderung Blindflug – das hat man ja heute bei den CI-Runs gesehen.

### 2. Watcher: Auto-Update via `git pull --ff-only`

Aktuell: Watcher läuft in einer Poll-Schleife. Wenn ich eine neue Version pushe, läuft die alte bis zum manuellen Neustart. Das ist ein **betriebliches Problem**:

- Vor jedem Poll-Durchlauf `git fetch origin && git diff HEAD origin/main --quiet` prüfen
- Wenn abweichend: `git pull --ff-only` + Skript-Neustart
- Das ist kein Luxus – ohne das hat man einen wartungsintensiven Daemon.

### 3. Rate-Limiting / Backoff – nicht Kosmetik, sondern Betriebsfähigkeit

GitHub API hat Rate Limits (5000 Requests/Stunde für authentifiziert). Der Watcher pollt `gh issue list` + Kommentare + Commit-Daten. Bei jedem Durchlauf sind das leicht 5-10 API-Calls. Wenn etwas schiefläuft (z.B. 403/429), knallt der Watcher aktuell durch – und das Journal hilft nur beim Debuggen, nicht beim Überleben.

- Ein smarter Backoff (Fehler → Intervall verdoppeln bis max 30min) macht den Watcher **produktionstauglich**.
- Ohne Backoff kann sich der Watcher selbst aussperren.

### 4. YAML-Validierung im CI

Das ist kein Kosmetikthema: Ein einziger YAML-Syntaxfehler im Workflow und GitHub Actions zeigt einen kaputten Workflow an. Man bekommt keinen Fehler im Log, sondern der Workflow "startet nicht". Ich habe das in der Praxis erlebt – man verliert Zeit.

- `yamllint` oder `action-validator` im CI wäre eine **einmalige, kleine Investition** mit sofortigem Return.

### 5. Issue-Template: Pfad-Beschränkung

Der Codex-Prompt sagt aktuell nur "Work only inside this repository checkout". Das ist vage. Ein konkretes Feld "Erlaubte Pfade" würde:

- Codex enger führen (weniger Halluzinationen)
- Sicherheit erhöhen (Codex ändert nicht versehentlich Workflow-Dateien)
- Die Wahrscheinlichkeit von `BLOCKED`-Entscheidungen senken

---

## 🎨 Nice-to-have / Kosmetik (nächstes Jahr, wenn der Loop läuft)

|Idee|Warum Kosmetik|
|---|---|
|Metriken/Statistik|Interessant, aber kein Betriebsproblem. Der Loop läuft oder nicht.|
|SHA-Pinning für Actions|Theoretisch sicherer, praktisch hat noch niemand `actions/checkout@v4` gekapert. Kostet nur Wartung beim Action-Update.|
|Event Log|Nett für Admins, bringt aber nichts für den Loop selbst.|
|Task Scheduler XML|Einmalig nützlich, danach egal.|
|Architecture-Diagramm|Schön für README, aber das README versteht man auch ohne.|
|Pester-Tests für Watcher|Wichtig **wenn** man den Watcher regelmäßig ändert. Momentan stabilisiert er sich – ich würde Tests erst schreiben, wenn ich das nächste Refactoring plane.|

---

## 🔥 Wenn ich das Projekt von Null neu entwerfen würde (Greenfield)

### Die Kernfrage: "Was ist der kleinste beweisbare Loop?"

**Mein Ansatz – radikal anders:**

1. **Kein GitHub Actions Workflow** als Einstiegspunkt  
    Stattdessen: Ein **einziges PowerShell-Skript**, das:
    
    - `gh issue list --label 2w:ready` pollt
    - Den Issue-Body an `codex exec` piped
    - Änderungen per `git commit + git push` zurückschreibt
    - Das Issue schließt/kommentiert
    - Fertig.
    
    Warum? GitHub Actions (prepare-Job auf `ubuntu-latest`, self-hosted Runner für Codex) verdoppelt die Architekturkomplexität. Der prepare-Job macht nichts, was nicht auch `gh` direkt könnte. **Der Workflow ist aktuell ein Middleman, den keiner braucht.**
    
2. **Der Workflow wird erst dazugeholt, wenn es weh tut**  
    Z.B. wenn:
    
    - Mehrere Nutzer gleichzeitig arbeiten (Concurrency)
    - Webhook-basierte Trigger statt Polling gewünscht sind
    - Secrets verwaltet werden müssen (die es nicht gibt)
3. **Single-Skript-Architektur:**
    
    - Ein Skript `loop.ps1` mit zwei Modi: `Poll` und `OneShot`
    - Eine Konfigurationsdatei `2w.config.json` (Repo, Intervalle, Labels)
    - Ein `install.ps1`, das `gh` auth, codex PATH und das Polling (per Scheduled Task) einrichtet
    - **Kein GitHub Actions**, **kein self-hosted Runner**, **kein YAML-Workflow** im Repo
4. **Erst wenn dieser Kern läuft, entscheide ich:**
    
    - Brauche ich Webhooks? → Dann GitHub Actions + `workflow_dispatch`-Workflow
    - Brauche ich Multi-User? → Dann self-hosted Runner mit separatem Service-Account
    - Brauche ich ChatGPT-Rückkanal? → Das ist bis heute ungelöst – der Watcher ist der beste Ansatz dafür

**Zusammengefasst:**

- Der **Workflow** ist aktuell Overengineering. Er war da, weil man dachte "GitHub Actions ist der Standardweg". Aber der 2W-Loop ist ein **lokales** Problem, das ein lokales Skript besser löst.
- Der **Watcher** ist der richtige Ansatz – ich würde ihn nur nicht als "Ergänzung" zum Workflow sehen, sondern **als das eigentliche System**.
- Der Workflow wäre dann optionaler Zusatz für Webhook-getriggerte Läufe, nicht der Kern.

---

**Realistische Prioritäten für die nächste Iteration (nur das, was wirklich zählt):**

1. **Auto-Update** (`git pull --ff-only` vor Poll) – ohne das bleibt der Watcher auf einer Version stehen
2. **Backoff bei API-Fehlern** – ohne das killt sich der Watcher bei Netzwerkproblemen selbst
3. **YAML-Validierung im CI** – produktionstauglicher Workflow
4. **Selbsttest-Modus** – einmalig bauen, dann weiß man, dass der Loop geht

Task Completed

## Ehrliche Analyse: Was bringt wirklich etwas? (Nicht umsetzen, nur Auflistung)

### 💎 Wirklich relevant – ohne das bleibt das System fragil

1. **Selbsttest-Mechanismus (K.O.-Kriterium)**  
    Niemand weiß aktuell, ob der Loop funktioniert, bevor er wirklich läuft. Ein `2W_READY: self-test`-Issue, das der Watcher selbst erzeugt, validiert und wieder aufräumt – das wäre der ultimative Proof. Ohne das ist jede Änderung Blindflug.
    
2. **Watcher Auto-Update (`git pull --ff-only`)**  
    Der Watcher läuft in einer Poll-Schleife. Wenn ich eine neue Version pushe, läuft die alte bis zum manuellen Neustart. Ein `git fetch && diff HEAD origin/main` vor jedem Durchlauf + Pull + Neustart wäre trivial und macht den Watcher wartbar.
    
3. **Rate-Limiting / Backoff**  
    Bei GitHub API 429/403 feuert der Watcher aktuell einfach weiter. Das kann ihn selbst aussperren (5k requests/h). Ein smarter Backoff (Fehler → Intervall verdoppeln bis max 30min) macht ihn produktionsfähig.
    
4. **YAML-Validierung im CI**  
    Ein YAML-Fehler im Workflow und GitHub Actions "startet nicht" – ohne Fehlermeldung. `yamllint` oder `action-validator` wäre eine kleine Investition mit sofortigem Return.
    
5. **Issue-Template: Pfad-Beschränkung**  
    Aktuell "Work only inside this repository checkout" – zu vage. Ein Feld "Erlaubte Pfade" würde Codex enger führen, Halluzinationen senken und Sicherheit erhöhen.
    

### 🎨 Nice-to-have / Kosmetik

- **Metriken/Statistik** → Interessant, aber der Loop läuft oder nicht
- **SHA-Pinning für Actions** → Niemand hat `actions/checkout@v4` gekapert
- **Event Log** → Nett, aber kein Betriebsproblem
- **Task Scheduler XML** → Einmalig nützlich
- **Architektur-Diagramm** → Schön, aber README funktioniert auch ohne
- **Pester-Tests** → Erst wenn ich das nächste Refactoring plane

### 🔥 Greenfield – wie ich es komplett neu machen würde

**Radikale Vereinfachung: Kein GitHub Actions Workflow als Kern.**

Der Workflow ist aktuell ein teurer Middleman: prepare-Job auf `ubuntu-latest` + self-hosted Runner für Codex. Der prepare-Job macht nichts, was `gh` nicht direkt könnte.

**Meine Single-Skript-Architektur:**

- Ein Skript `loop.ps1` mit Poll/OneShot-Modus
- Eine JSON-Konfiguration (`2w.config.json`)
- Ein `install.ps1` für `gh auth`, codex PATH und Task Scheduler
- **Kein GitHub Actions**, **kein self-hosted Runner**, **kein YAML-Workflow**

Der Workflow kommt erst dazu, wenn:

- Webhook-basierte Trigger nötig sind (statt Polling)
- Mehrere Nutzer gleichzeitig arbeiten
- Secrets verwaltet werden müssen

Der Watcher ist der richtige Ansatz – aber als **das eigentliche System**, nicht als Ergänzung zum Workflow.

### Realistische Top 3 für die nächste Iteration

1. Auto-Update (`git pull --ff-only`)
2. Backoff bei API-Fehlern
3. YAML-Validierung im CI