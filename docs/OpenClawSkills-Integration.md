# OpenClaw Skills Integration

This repository now includes a helper script for fetching the `awesome-openclaw-skills` listing from GitHub.

It is intended as a local cataloging and discovery helper, not as a runtime dependency for WinTunePro.

## Usage

Run the helper from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Fetch-OpenClawSkills.ps1
```

By default, the command downloads the upstream OpenClaw skills README and saves:

- `docs/OpenClawSkills.md`
- `docs/OpenClawSkills.csv`

### Optional modes

- `-Mode Readme` - only save the raw markdown listing
- `-Mode Csv` - export parsed skill entries into a CSV catalog
- `-Quiet` - suppress informational output

Example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Fetch-OpenClawSkills.ps1 -Mode Csv
```
