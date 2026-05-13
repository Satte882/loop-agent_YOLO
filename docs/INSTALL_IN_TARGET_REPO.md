# Install in target repository

## Ziel

`loop-agent_YOLO` soll als kleines Starterkit in beliebigen Zielrepos nutzbar sein.

## Zielbild

Ein Zielrepo braucht nur zwei Dateien:

- `.github/workflows/2w-codex.yml`
- `.github/ISSUE_TEMPLATE/2w-workblock.yml`

Optional zusätzlich:

- `.gitignore`-Eintrag für `.2w/`

## Installation

1. Kopiere `templates/2w-local-codex.yml` aus diesem Repo in das Zielrepo nach `.github/workflows/2w-codex.yml`.
2. Kopiere `templates/ISSUE_TEMPLATE/2w-workblock.yml` in das Zielrepo nach `.github/ISSUE_TEMPLATE/2w-workblock.yml`.
3. Stelle sicher, dass im Zielrepo GitHub Actions aktiviert ist.
4. Stelle sicher, dass ein self-hosted Runner für das Zielrepo verfügbar ist.
5. Stelle sicher, dass `codex` auf dem Runner im PATH liegt.
6. Stelle sicher, dass `codex exec` ohne interaktive Anmeldung läuft.

## Start

Ein neues Issue startet den Lauf, wenn eine dieser Bedingungen gilt:

- Titel beginnt mit `2W_READY:`
- Label `2w:ready` ist gesetzt

## Einfaches Nutzungsmodell

ChatGPT erstellt ein Issue mit Ziel und Akzeptanzkriterien. Der Runner arbeitet. Der Workflow committet. Das Issue bekommt einen Ergebnis-Kommentar. ChatGPT prüft den Commit.

## Kein API-Key im Standardpfad

Der Standardpfad nutzt lokale Codex CLI. Es wird kein `OPENAI_API_KEY` verlangt.

## Begrenzung

Dieses Starterkit installiert keinen Runner automatisch und meldet Codex nicht automatisch an. Diese zwei Schritte bleiben lokale Voraussetzungen.