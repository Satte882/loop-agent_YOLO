# Auth with local Codex CLI

## Ziel

Der Standardpfad von `loop-agent_YOLO` soll keinen `OPENAI_API_KEY` benötigen.

## Modell

`loop-agent_YOLO` ruft lokal `codex exec` auf einem self-hosted Runner auf. Die Authentifizierung liegt vollständig bei der lokal installierten Codex CLI.

## Wichtig

Dieses Repository kann nicht garantieren, dass ein ChatGPT-Plus-Login automatisch für nicht-interaktive `codex exec`-Läufe im GitHub Actions Runner funktioniert.

Was dieses Repo garantiert:

- Der Standardworkflow enthält keinen `OPENAI_API_KEY`.
- Der Standardworkflow nutzt nicht `openai/codex-action@v1`.
- Der Standardworkflow ruft `codex exec` lokal auf.

Was lokal validiert werden muss:

- `codex` ist im PATH des self-hosted Runners.
- `codex --version` funktioniert.
- `codex exec` läuft ohne interaktive Browser-Anmeldung.
- Der Runner-Prozess sieht dieselbe Codex-Session wie der Nutzerkontext.

## Entscheidung

API-Key-Nutzung ist im Standardpfad ausgeschlossen. Ein API-Key-Fallback ist nicht Teil von 2W v0.