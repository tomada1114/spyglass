# Development task runner — requires Just (https://just.systems)
# All commands also work without Just by running the underlying commands directly
# (see CONTRIBUTING.md). Tools come from mise (mise.toml pins the versions).

# Show available recipes
default:
    @just --list

# Install pinned tools, git hooks, and generate the Xcode project
install:
    mise install
    if git rev-parse --git-dir >/dev/null 2>&1; then git config core.hooksPath .githooks; else echo "Skipping git hook installation (not a Git repository)."; fi
    mise exec -- xcodegen generate
    @if command -v xcodebuild >/dev/null 2>&1 && [ "$(xcodebuild -version | head -n1 | awk '{print $2}')" != "$(cat .xcode-version)" ]; then echo "warning: local Xcode $(xcodebuild -version | head -n1 | awk '{print $2}') differs from the CI-pinned $(cat .xcode-version) — results may diverge from CI"; fi

# Regenerate Spyglass.xcodeproj from project.yml
generate:
    mise exec -- xcodegen generate

# Format code
fmt:
    mise exec -- swiftformat .

# Run formatters and linters in check mode
lint:
    mise exec -- swiftformat --lint .
    mise exec -- swiftlint lint --strict --quiet
    mise exec -- shellcheck scripts/*.sh .githooks/pre-commit
    if [ -d .github/workflows ]; then mise exec -- actionlint; else echo "Skipping actionlint (no workflows yet)."; fi

# Run tests with the 80% line-coverage floor on SpyglassCore
test:
    scripts/coverage.sh

# Build the app (Debug)
build:
    mise exec -- xcodegen generate
    set -o pipefail && xcodebuild -project Spyglass.xcodeproj -scheme Spyglass -configuration Debug -derivedDataPath build/dev-derived-data build | mise exec -- xcbeautify --quiet

# Build (Debug) and launch the app, left running until you quit it
run: build
    open build/dev-derived-data/Build/Products/Debug/Spyglass.app

# Run the XCUITest launch test (may prompt for Accessibility permission on first local run)
uitest:
    mise exec -- xcodegen generate
    rm -rf build/LaunchUITests.xcresult
    set -o pipefail && xcodebuild test -project Spyglass.xcodeproj -scheme Spyglass -destination 'platform=macOS' -derivedDataPath build/dev-derived-data -resultBundlePath build/LaunchUITests.xcresult | mise exec -- xcbeautify

# Build Release and assert the app launches and stays alive
smoke:
    scripts/smoke_launch.sh

# Run all checks: format, lint, test, build (CI's app job adds uitest + smoke)
check: fmt lint test build

# Remove build artifacts and the generated project
clean:
    rm -rf build Packages/SpyglassKit/.build Spyglass.xcodeproj
