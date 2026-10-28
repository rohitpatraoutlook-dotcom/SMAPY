# SMAPY

SMAPY is a smartphone-first Python development environment
with a premium monochrome interface.

## Current phase

Phase 1: UI foundation and automated Android APK builds.

The Linux userspace, Python execution engine, notebook kernel,
and offline package vault are not implemented yet.

## Build

Push the project to GitHub on the `main` branch.
GitHub Actions will compile the Android APK.

To download the APK:
GitHub -> Actions -> SMAPY Android APK -> Artifacts.

## Planned architecture

- Flutter Android UI
- Linux ARM64 userspace
- Local Python runtime
- Jupyter-compatible notebooks
- Offline package vault
- Automated compatibility tests

Package support will be verified per runtime and architecture.
