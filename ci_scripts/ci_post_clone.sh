#!/bin/sh
# Xcode Cloud runs this after cloning. The Xcode project is generated from project.yml, MLX needs the Metal toolchain,
# and Xcode Cloud disables automatic package resolution, so the packages are resolved here.
set -e
cd "$CI_PRIMARY_REPOSITORY_PATH"
brew install xcodegen

# Xcode Cloud numbers builds from 1; App Store Connect already has higher numbers for this version.
BUILD=$((CI_BUILD_NUMBER + ${BUILD_NUMBER_OFFSET:-100}))
export BUILD
perl -pi -e 's/CURRENT_PROJECT_VERSION: "\d+"/CURRENT_PROJECT_VERSION: "$ENV{BUILD}"/; s/^(\s+)GENERATE_INFOPLIST_FILE: YES/$1GENERATE_INFOPLIST_FILE: YES
$1SWIFT_ACTIVE_COMPILATION_CONDITIONS: "\$(inherited) REASONING_API"/' project.yml
xcodegen generate
echo "Build number $BUILD"

xcodebuild -downloadComponent MetalToolchain || true
xcodebuild -resolvePackageDependencies -project Adiuvaret.xcodeproj -scheme Adiuvaret
