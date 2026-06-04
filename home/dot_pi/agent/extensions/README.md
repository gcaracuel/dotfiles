# Pi Guardrails Configuration

This directory contains the **global** pi-guardrails config, applied to all Pi sessions.

## Global config (this file)

`guardrails.json` → `~/.pi/agent/extensions/guardrails.json`

Applies to every project. Managed as a chezmoi dotfile.

## Per-project config

Create `.pi/extensions/guardrails.json` in any project root for project-specific settings. It merges with global:

| Field | Merge behavior |
|---|---|
| `policies.rules` | Dedup by `rule.id`. Order: builtin → global → local → memory. Later wins for same id. |
| `permissionGate.customPatterns` | First found wins: memory → local → global |
| `pathAccess.allowedPaths` | Union — all paths from all scopes merged |
| `pathAccess.mode` | Local overrides global |
| Everything else | Local overrides global entirely |

**Scope hierarchy** (last wins for non-merged fields):
1. `global` → `~/.pi/agent/extensions/guardrails.json`
2. `local` → `.pi/extensions/guardrails.json` (per project)
3. `memory` → in-session changes via `/guardrails:settings`

### Example per-project config

```json
{
  "$schema": "https://unpkg.com/@aliou/pi-guardrails@0.13.1/schema.json",
  "pathAccess": {
    "mode": "allow",
    "allowedPaths": ["/tmp", "/usr/local/share"]
  },
  "policies": {
    "rules": [
      {
        "id": "build-artifacts",
        "patterns": [{ "pattern": "dist/**" }],
        "protection": "noAccess"
      }
    ]
  }
}
```

See full schema at [schema.json](https://unpkg.com/@aliou/pi-guardrails@latest/schema.json) or use `/guardrails:settings` in Pi.
