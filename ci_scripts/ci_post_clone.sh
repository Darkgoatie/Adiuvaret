#!/bin/sh
# Xcode Cloud runs this after cloning. The Xcode project is generated from project.yml, and MLX needs the Metal toolchain.
set -e
cd "$CI_PRIMARY_REPOSITORY_PATH"
brew install xcodegen
xcodegen generate
xcodebuild -downloadComponent MetalToolchain || true
