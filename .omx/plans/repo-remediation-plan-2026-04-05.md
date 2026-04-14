# WinTunePro remediation plan

Date: 2026-04-05  
Workspace: `E:\WinTunePro`

## Requirements Summary

- Restore the repository to a minimally safe, buildable, testable state before feature expansion.
- Preserve the existing PowerShell-first product direction unless evidence shows the native wrapper should replace it.
- Prioritize fixes that reduce user risk first: exposed secrets, parse failures, unsafe drift between entrypoints, and missing verification.
- Avoid broad feature work until one canonical startup path and a safe verification loop exist.

## Evidence Summary

- Plaintext secret in `wintune_commands.txt:44`
- Broken PowerShell entrypoint strings/structure in `WinTunePro.ps1:19`, `WinTunePro.ps1:20`, `WinTunePro.ps1:242`
- Duplicate/overlapping launch surfaces:
  - `WinTune.ps1:122`
  - `LaunchWinTune.ps1:14`
  - `LaunchWinTune.ps1:94`
  - `WinTune.bat:17`
- Native wrapper is stubbed:
  - `NativeBuild/WinTunePro/MainWindow.xaml.cs:28`
  - `NativeBuild/WinTunePro/MainWindow.xaml.cs:44`
- Encoding-corrupted TronScript output breaks parsing:
  - `Modules/TronScript/TronScript.ps1:134`
  - `Modules/TronScript/TronScript.ps1:226`
- Generated/runtime artifacts are committed:
  - `Backups/`
  - `Logs/`
  - `Reports/`
  - `Data/Rollback_unknown.json`
- Ad hoc maintenance/test scripts are path-bound to one machine:
  - `test1.ps1:2`
  - `rebuild.ps1:1`
  - `check.ps1:1`

## Acceptance Criteria

1. No plaintext secrets remain in repository-tracked files.
2. `WinTune.ps1`, chosen canonical helpers, and retained module files parse without PowerShell parser errors.
3. Only one canonical end-user launch path is documented and supported.
4. Generated artifacts are excluded from source control via `.gitignore` and repository layout guidance.
5. A safe verification workflow exists for syntax/load checks and non-destructive smoke tests.
6. The role of `NativeBuild/` is explicitly decided: integrated, deferred, or removed.

## ADR

### Decision
Stabilize the PowerShell application first, then decide whether to integrate or drop the native WPF wrapper.

### Drivers
- The PowerShell app contains the real feature surface.
- Current failures are mostly repository hygiene and script correctness, not missing feature breadth.
- The native wrapper is presently a simulation layer, not the production runtime.

### Alternatives considered
- **Promote `NativeBuild/` immediately** — rejected for now because the wrapper only simulates script execution and the environment lacks a .NET SDK for reliable validation.
- **Keep all entrypoints active** — rejected because drift is already visible and blocks safe maintenance.
- **Start with feature additions** — rejected because current parse/security issues make further expansion unsafe.

### Why chosen
This path removes immediate risk quickly and creates a stable base for later refactor or feature work.

### Consequences
- Short-term work focuses on deletion, consolidation, and verification rather than new features.
- Some existing convenience scripts may be retired.
- NativeBuild may be temporarily frozen until the PowerShell runtime is trustworthy.

### Follow-ups
- After stabilization, split monolithic scripts into smaller tested modules.
- Reassess UI strategy: PowerShell UI only vs fully integrated native shell.

## Implementation Plan

### Phase 0 — Contain immediate risk

1. Remove the plaintext secret from `wintune_commands.txt` and replace the note with a redacted placeholder.
2. Assume the exposed credential is compromised and rotate it outside the repo.
3. Add a root `.gitignore` to exclude:
   - `Logs/`
   - `Reports/`
   - `Backups/`
   - `Data/*.json` runtime snapshots where appropriate
   - machine-local helper outputs such as `errors_found.txt`
4. Rename or relocate backup artifacts that are not executable scripts, especially `Backups/Core_Config_20260404_212210.ps1`, so parser-based tooling no longer treats them as source.

### Phase 1 — Make the PowerShell codebase parse-clean

1. Fix `WinTunePro.ps1` syntax issues first:
   - interpolate `${f}` safely in the failing strings near lines 19–20
   - remove or relocate the stray report block around line 242
   - repair mismatched braces near the later WinForms sections
2. Repair `Modules/TronScript/TronScript.ps1`:
   - replace encoding-corrupted separator text with ASCII-safe output
   - re-run parser validation after each edit
3. Run a repo-wide parser sweep only on intended source files and keep backup/generated folders out of that check.

### Phase 2 — Choose one canonical launch path

1. Compare the responsibilities of:
   - `WinTune.ps1`
   - `WinTunePro.ps1`
   - `LaunchWinTune.ps1`
   - `WinTune.bat`
2. Keep one user-facing entrypoint, likely `WinTune.ps1` plus optional `WinTune.bat` launcher.
3. Convert the others into either:
   - thin wrappers, or
   - archived/deprecated files removed from the main path
4. Document the canonical startup path in a new `README.md`.

### Phase 3 — Clean the repo surface

1. Remove accidental empty directories `-Force/` and `-p/` if they are truly unused.
2. Audit machine-local scripts:
   - `test1.ps1`
   - `check.ps1`
   - `rebuild.ps1`
   - `trace*.ps1`
3. Keep only scripts that are:
   - portable
   - documented
   - safe to run
4. Move one-off repair utilities under `Tools/` or archive them out of the product path.

### Phase 4 — Establish safe verification

1. Add a non-destructive validation script, for example `Tools/Validate.ps1`, that:
   - runs the PowerShell parser against source files
   - dot-sources core modules in test mode only
   - verifies required directories/config files exist
2. Replace `test1.ps1` with a safer, narrower smoke-test flow that never performs destructive actions by default.
3. If Pester is already available on target systems, add basic parser/load tests without introducing new external dependencies.

### Phase 5 — Decide the future of `NativeBuild/`

1. Treat `NativeBuild/` as deferred until Phase 1–4 pass.
2. Decide one of:
   - **Defer**: keep it but mark as prototype in docs
   - **Integrate**: wire real PowerShell execution into the wrapper and validate with a .NET SDK
   - **Remove**: delete it from the shipping path
3. If retained, fix current issues:
   - command typo at `NativeBuild/WinTunePro/MainWindow.xaml.cs:28`
   - simulation-only behavior at `NativeBuild/WinTunePro/MainWindow.xaml.cs:44`

### Phase 6 — Refactor for maintainability

1. Split `WinTune.ps1` into orchestration only.
2. Move UI event wiring out of `UI/MainWindow.ps1` into smaller feature-specific files.
3. Deduplicate feature helpers that exist in both root scripts and modules.
4. Revisit very large core files:
   - `Core/ReportGenerator.ps1`
   - `Core/ProfileManager.ps1`
   - `Core/ToolManager.ps1`
   - `Core/HealthScore.ps1`
   - `Core/Watchdog.ps1`

## Risks and Mitigations

- **Risk:** Fixing syntax may change runtime behavior.  
  **Mitigation:** Prefer minimal parser-only edits first; verify after every edit.

- **Risk:** Removing duplicate entrypoints may break existing user habits.  
  **Mitigation:** keep temporary wrapper shims with deprecation messages.

- **Risk:** Some modules are intentionally dangerous by design.  
  **Mitigation:** keep verification read-only/test-mode by default and avoid executing optimization actions during validation.

- **Risk:** `NativeBuild/` cannot be validated here due to missing SDK.  
  **Mitigation:** explicitly defer full native integration until a machine with the .NET SDK is available.

## Verification Steps

1. Run PowerShell parser validation over retained source files.
2. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\WinTune.ps1 -Help`
3. Run the new validation script in non-destructive mode.
4. Confirm `WinTunePro.ps1` either:
   - parses cleanly as a retained wrapper, or
   - is removed/deprecated from the supported path.
5. Confirm no tracked files contain known secret literals.
6. On a machine with .NET SDK installed, run:
   - `dotnet build .\NativeBuild\WinTunePro.sln -nologo`
   if `NativeBuild/` remains in scope.

## Recommended Execution Order

1. Secret removal and `.gitignore`
2. Parse fixes
3. Entry-point consolidation
4. Validation script/tests
5. NativeBuild decision
6. Refactor/cleanup passes

## Changed files

- `.omx/plans/repo-remediation-plan-2026-04-05.md`
