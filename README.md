# WinTunePro

WinTunePro is a PowerShell-first Windows system tuning toolkit with optional wrapper launchers and a prototype native WPF shell under `NativeBuild/`.

## Current supported entrypoint

- Canonical script: `WinTune.ps1`

Compatibility wrappers currently forward to the canonical script:

- `WinTunePro.ps1`
- `LaunchWinTune.ps1`
- `WinTune.bat`

## Safe validation

Run the non-destructive validation script before and after changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Validate.ps1 -SmokeHelp
```

Legacy `test1.ps1` now forwards to the same validation flow:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test1.ps1 -SmokeHelp
```

## Repository layout

- `Core/` - application infrastructure
- `Modules/` - feature modules
- `UI/` - PowerShell UI
- `NativeBuild/` - prototype native wrapper
- `Tools/` - maintenance and validation scripts
- `Tests/` - safe smoke-test scripts
- `docs/` - diagrams and notes

Generated/runtime artifacts are intentionally excluded from version control:

- `Logs/`
- `Reports/`
- `Backups/`

## Notes

- Treat `NativeBuild/` as experimental until it is validated on a machine with the .NET SDK installed.
- Prefer `WinTune.ps1` for documentation, automation, and future integration work.
- `install.sh` and `opencode.json` are retained as external agent/tooling metadata, not as part of the WinTunePro runtime.
