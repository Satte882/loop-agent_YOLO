# Validate local Codex CLI login

## Ziel

Vor dem ersten 2W-Lauf muss lokal geprüft werden, ob `codex exec` im self-hosted Runner-Kontext ohne interaktive Anmeldung funktioniert.

## Was erfüllt sein muss

- `codex` ist installiert.
- `codex` liegt im PATH des Runner-Prozesses.
- `codex --version` funktioniert.
- `codex exec` kann einen kleinen Testauftrag ausführen.
- Der Testauftrag erzeugt keine Browser-Login-Aufforderung.
- Der Runner nutzt denselben Nutzerkontext oder dieselbe Codex-Session wie der lokal angemeldete Nutzer.

## Minimaler Funktionstest

Der erste Test sollte kein Produktivrepo verändern. Geeignet ist ein kleines Test-Issue in `loop-agent_YOLO`, das nur eine Markdown-Zeile ergänzt oder eine neue Testdatei in `docs/` erzeugt.

## Erwartetes Ergebnis

Der Workflow läuft bis `2W_DONE`, erzeugt einen Commit oder meldet sauber `commit=none`, und kommentiert das Issue mit Teststatus.

## Fehlerbilder

| Fehler | Bedeutung |
|---|---|
| `codex CLI not found` | Codex ist nicht im PATH des Runner-Prozesses |
| Browser-Login erscheint | Non-interactive Runner-Kontext ist nicht authentifiziert |
| `codex exec` kennt Flag nicht | Installierte Codex-Version passt nicht zum Workflow |
| Workflow hängt | Codex wartet wahrscheinlich interaktiv auf Eingabe |

## Entscheidung

Erst wenn dieser Test grün ist, ist das Ziel "ohne API-Key mit lokaler Codex CLI" praktisch bestätigt.