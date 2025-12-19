#!/bin/bash
set -e

# Config
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBRARY_DIR="${REPO_ROOT}/library"
AAR_PATH="${LIBRARY_DIR}/build/outputs/aar/c2pa-release.aar"

# 1. Check Pre-requisites
if ! command -v gh &> /dev/null; then
    echo "❌ Error: 'gh' CLI is not installed."
    exit 1
fi

# Parse args
TAG_NAME="${1}"
if [ -z "${TAG_NAME}" ]; then
    echo "❌ Error: Missing tag name (e.g. v0.1.0)"
    exit 1
fi

SKIP_BUILD=false
if echo "$*" | grep -q -- "--skip-build"; then SKIP_BUILD=true; fi 

# 2. Build Artifacts
if [ "$SKIP_BUILD" = "true" ]; then
    echo "⏩ --skip-build flag detected. Skipping AAR build..."
    if [ ! -f "${AAR_PATH}" ]; then
        echo "❌ Error: AAR not found at ${AAR_PATH}. Cannot skip build."
        exit 1
    fi
else
    echo "📦 Building Android Native Libs (from source)..."
    BUILD_FROM_SOURCE=true make release-android-libs

    echo "📦 Assembling Android AAR..."
    BUILD_FROM_SOURCE=true ./gradlew :library:assembleRelease

    # Check result
    if [ ! -f "${AAR_PATH}" ]; then
        echo "❌ Error: Build failed, ${AAR_PATH} not found."
        exit 1
    fi
fi

# 3. Create Release & Upload
REPO_URL=$(git remote get-url origin | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')
echo "🚀 Creating GitHub Release '${TAG_NAME}' on ${REPO_URL}..."

# Use gh release create (it handles existing release check via --clobber or view)
if gh release view "${TAG_NAME}" &> /dev/null; then
    echo "⚠️  Release '${TAG_NAME}' already exists. Uploading missing assets..."
else
    gh release create "${TAG_NAME}" \
        --title "C2PA Android ${TAG_NAME}" \
        --notes "Automated release of C2PA Android AAR.\n\nBuilt from c2pa-rs submodule."
fi

echo "⬆️  Uploading AAR..."
gh release upload "${TAG_NAME}" "${AAR_PATH}#c2pa.aar" --clobber

echo ""
echo "✅ Success! Release available at:"
echo "   ${REPO_URL}/releases/tag/${TAG_NAME}"
echo ""
echo "👉 Use the following in your main app's download task:"
echo "   URL: ${REPO_URL}/releases/download/${TAG_NAME}/c2pa.aar"
