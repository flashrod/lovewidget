#!/bin/bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <version> [--repo owner/name] [--skip-gh-release]"
  echo "Example: $0 1.0.1 --repo flashrod/LoveWidget"
  exit 1
fi

VERSION="$1"
shift || true

REPO_OVERRIDE=""
SKIP_GH_RELEASE="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      REPO_OVERRIDE="${2:-}"
      shift 2
      ;;
    --skip-gh-release)
      SKIP_GH_RELEASE="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

APP_NAME="LoveWidget"
CASK_FILE="Casks/lovewidget.rb"
DMG_PATH=".release/${APP_NAME}-${VERSION}.dmg"

if [ ! -f "build-release.sh" ]; then
  echo "ERROR: Run this script from repo root."
  exit 1
fi

if [ ! -f "$CASK_FILE" ]; then
  echo "ERROR: Missing cask file at $CASK_FILE"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is required. Install with: brew install gh"
  exit 1
fi

echo "==> Building DMG for version ${VERSION}"
./build-release.sh "$VERSION"

if [ ! -f "$DMG_PATH" ]; then
  echo "ERROR: Expected DMG not found: $DMG_PATH"
  exit 1
fi

echo "==> Calculating SHA-256"
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
if [ -z "$SHA256" ]; then
  echo "ERROR: Failed to compute SHA-256"
  exit 1
fi
echo "    $SHA256"

echo "==> Updating cask version and checksum"
sed -i '' -E "s/^  version \"[^\"]+\"/  version \"${VERSION}\"/" "$CASK_FILE"
sed -i '' -E "s/^  sha256 \"[a-f0-9]+\"/  sha256 \"${SHA256}\"/" "$CASK_FILE"

if [ "$SKIP_GH_RELEASE" = "false" ]; then
  if [ -n "$REPO_OVERRIDE" ]; then
    REPO="$REPO_OVERRIDE"
  else
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
  fi

  if [ -z "$REPO" ]; then
    echo "ERROR: Could not resolve GitHub repo. Use --repo owner/name"
    exit 1
  fi

  TAG="v${VERSION}"

  echo "==> Creating or updating GitHub release ${TAG} on ${REPO}"
  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "    Release exists; uploading DMG and overwriting asset if needed"
    gh release upload "$TAG" "$DMG_PATH" --repo "$REPO" --clobber
  else
    gh release create "$TAG" "$DMG_PATH" \
      --repo "$REPO" \
      --title "LoveWidget ${TAG}" \
      --notes "Release ${TAG}"
  fi
fi

echo ""
echo "============================================"
echo "Release prep complete"
echo "- DMG: $DMG_PATH"
echo "- SHA: $SHA256"
echo "- Updated: $CASK_FILE"
echo "============================================"
echo ""
echo "Next:"
echo "1) Commit and push this repo changes"
echo "2) Update your tap repo with the updated cask file"
echo "3) Partner installs via: brew tap flashrod/tap && brew install --cask lovewidget"
