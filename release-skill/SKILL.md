---
name: app-release
description: Automates the release process for Skill Lake app, including version bumping, building, packaging, and publishing to GitHub and Homebrew.
---

# app-release

Use this skill when you need to publish a new version of the Skill Lake application.

## Workflow

1.  **Check Prerequisites**: Ensure you are on the `main` branch and have no uncommitted changes.
2.  **Determine Version**: Ask the user for the new version number (e.g., `1.1.8`) if not provided.
3.  **Execute Release**: Run the `./release.sh` script with the new version as an argument.
4.  **Verification**: Confirm that the build succeeded, the DMG was created, and the release was pushed to GitHub and the Homebrew tap.

## Usage

```bash
./release.sh <new_version>
```

Example:
```bash
./release.sh 1.1.8
```

## Features

-   **Code Validation**: Automatically runs `flutter analyze` and checks formatting before building.
-   **Automated Build**: Builds the macOS app in release mode.
-   **DMG Packaging**: Creates a signed DMG package for easy installation.
-   **Git Automation**: Handles version bumping in `pubspec.yaml`, commits, tagging, and pushing.
-   **GitHub Integration**: Creates or updates a GitHub Release and uploads the DMG.
-   **Homebrew Sync**: Automatically updates the Homebrew Cask in the dedicated tap repository.
-   **UI Sync**: Ensures the version displayed in the "About" dialog matches the released version using `package_info_plus`.
