# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**liquid_ai** is a Dart/Flutter package providing AI integrations. The project is set up for pub.dev publication with proper versioning, release management, and GitHub Actions workflows.

## Quick Start

### Setup
```bash
dart pub get
```

### Common Commands

**Format code:**
```bash
dart format lib/ test/ example/
```

**Analyze code:**
```bash
dart analyze
```

**Run tests:**
```bash
dart test
```

**Run a single test:**
```bash
dart test test/liquid_ai_test.dart
```

**Watch mode (re-run tests on file changes):**
```bash
dart test --watch
```

## Project Structure

- **`lib/`** - Main package source code
  - `liquid_ai.dart` - Main library export file
- **`test/`** - Unit and widget tests following the `_test.dart` naming convention
- **`example/`** - Example applications demonstrating package usage (currently empty)
- **`.github/workflows/`** - CI/CD pipelines:
  - `checks.yml` - Runs linting, analysis, and tests on every PR
  - `publish.yml` - Auto-publishes to pub.dev on GitHub releases
  - `release-please.yml` - Automated versioning and release notes generation

## Development Workflow

### Pre-commit Hooks
This project uses lefthook for pre-commit automation (configured in `lefthook.yml`):
- Automatically formats staged Dart files with `dart format`
- Runs `dart analyze` on staged files
- Fixes are staged automatically

To bypass hooks (not recommended):
```bash
git commit --no-verify
```

### Code Quality

**Linting rules:** This project uses `flutter_lints` as defined in `analysis_options.yaml`. Follow the linter's guidance and run analysis before committing.

**Line length:** Keep lines to 80 characters or fewer.

**Naming conventions:**
- `PascalCase` for classes
- `camelCase` for variables, functions, methods, and enum values
- `snake_case` for filenames

### Testing Guidelines

- Write unit tests for all public APIs
- Follow the Arrange-Act-Assert pattern
- Test files live in `test/` with `_test.dart` suffix
- Run tests locally before pushing: `dart test`

## Architecture & Design Principles

### API Design
Since this is a package for public consumption:
- **Consider the User:** API should be intuitive and easy to use correctly
- **Documentation is Essential:** Document all public APIs with dartdoc comments
- **Minimal Dependencies:** Keep external dependencies to a minimum
- **Stable Interfaces:** Avoid breaking changes within a major version

### Code Organization
- Export all public APIs from `lib/liquid_ai.dart`
- Keep private implementation details in the `lib/src/` folder (use private exports)
- Group related functionality in the same file when possible
- Use meaningful, descriptive names that avoid abbreviations

### Documentation Requirements
All public APIs must have dartdoc comments:
- Start with a single-sentence summary ending with a period
- Add a blank line after the summary for additional context
- Include parameter and return value descriptions
- Add usage examples for non-obvious APIs

Example:
```dart
/// Transforms the input string to uppercase.
///
/// Returns a new string with all characters converted to uppercase.
String toUpperCase(String input) => input.toUpperCase();
```

### Null Safety & Error Handling
- Write soundly null-safe code; avoid `!` unless the value is guaranteed non-null
- Throw appropriate exceptions for error cases
- Document exceptions that public APIs can throw
- Avoid silent failures

## Release Management

This project uses **Release Please** for automated versioning and releases:
- Version follows semantic versioning (see `pubspec.yaml` and `release-please-manifest.json`)
- Commit messages follow the Conventional Commits specification
- Changelog is auto-generated from commit messages

Commit message format:
```
type(scope): description

body (optional)
```

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`

## GitHub Actions Workflows

**Checks (on every PR):**
- Runs `dart format --set-exit-if-changed`
- Runs `dart analyze`
- Runs all tests with `dart test`

**Publish (on GitHub release):**
- Publishes the package to pub.dev (requires credentials configured)

**Release Please (on every push to main):**
- Automatically creates a release PR with updated version and CHANGELOG
- Merge the PR to trigger a GitHub release (which then publishes)

## Important Notes

- **This is a package, not an app:** There's no main entry point; the library is the product
- **Minimal example:** The `example/` directory is currently empty; add examples when features are ready
- **Backward Compatibility:** Follow semantic versioning; breaking changes require a major version bump
- **pub.dev:** The package is prepared for public publication (see `LICENSE`, `README.md`, and homepage/repository in `pubspec.yaml`)

## Style Guide Summary

- **Effective Dart:** Follow https://dart.dev/effective-dart
- **Concise & Declarative:** Prefer functional and declarative patterns
- **SOLID Principles:** Apply throughout the codebase
- **Immutability:** Prefer immutable data structures
- **Comments:** Explain *why*, not *what*; code should be self-explanatory
- **Functions:** Keep them short with a single purpose (ideally under 20 lines)
