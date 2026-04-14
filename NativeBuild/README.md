# NativeBuild status

`NativeBuild/` is currently a prototype WPF wrapper around the canonical PowerShell application.

Current status:

- Not validated in this workspace because no .NET SDK is installed here
- UI actions are still simulation/prototype actions, not a production-integrated execution path
- Canonical runtime remains `..\WinTune.ps1`

Until the native shell is fully integrated and build-verified, prefer:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\WinTune.ps1
```
