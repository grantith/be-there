# Release Draft

This project ships two artifacts per release:

## 1) Source zip
Include:
- `be-there.ahk`
- `src/`
- `tools/`
- `config/config.example.json`
- `README.md`, `LICENSE`, `LICENSES/`

## 2) Compiled zip
Include:
- `be-there.exe`
- `tools/` (optional; requires AutoHotkey for `.ahk` tools)
- `config/config.example.json`
- `README.md`, `LICENSE`, `LICENSES/`

## Checklist
- Update `README.md` if config/schema changed.
- Update `docs/INSTALL.md` if paths or requirements changed.
- Verify `config/config.example.json` matches defaults.
- (Optional) test start/reload and Command Overlay in both variants.

## GitHub Release Flow
1. Merge to `main`.
2. Create a tag: `git tag vX.Y.Z`.
3. Push tags: `git push origin vX.Y.Z`.
4. GitHub Actions builds and publishes release assets:
   - `be-there-source-vX.Y.Z.zip`
   - `be-there-vX.Y.Z-win64.zip`
   - `be-there-vX.Y.Z.exe`

## Release Candidates
- Use a prerelease tag like `vX.Y.Z-rc.1`.
- The workflow marks tags containing `-rc`, `-beta`, or `-alpha` as prerelease.

## Workflow Dispatch (Test Release)
- Manually run the workflow and supply a `version` (e.g., `v0.0.0-rc.0`).
- Set `prerelease` to `true` to keep it out of stable releases.

## Dev Builds
- The `dev-build` workflow runs on `main` and uploads artifacts to the workflow run.
- Artifacts are accessible from the Actions run page and are public for public repos.

## Local Build
Use the helper script to build locally without GitHub Actions:
```
powershell -ExecutionPolicy Bypass -File tools/build_release.ps1 -Version dev
```
Artifacts are written to `dist/`.

## Tooling
- The build script also exports `config.example.json` into `dist/` for quick inspection.
