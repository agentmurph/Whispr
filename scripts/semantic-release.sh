#!/bin/bash
# semantic-release.sh — Analyze conventional commits and determine next version.
# Sourced by the release workflow. Sets: CURRENT_VERSION, NEW_VERSION, BUMP, RELEASE_NOTES
set -euo pipefail

# Get latest tag or default to v0.0.0
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
CURRENT_VERSION="${LATEST_TAG#v}"

echo "Latest tag: ${LATEST_TAG} (version ${CURRENT_VERSION})"

# Parse current version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Analyze commits since last tag
if [ "$LATEST_TAG" = "v0.0.0" ]; then
  COMMITS=$(git log --pretty=format:"%s|||%h" --no-merges)
else
  COMMITS=$(git log "${LATEST_TAG}..HEAD" --pretty=format:"%s|||%h" --no-merges)
fi

if [ -z "$COMMITS" ]; then
  echo "No new commits since ${LATEST_TAG}"
  BUMP="none"
  NEW_VERSION="$CURRENT_VERSION"
  RELEASE_NOTES=""
  return 0 2>/dev/null || exit 0
fi

# Categorize commits
BUMP="none"
FEATS=""
FIXES=""
DOCS=""
CHORES=""
BREAKING=""
OTHER=""

while IFS= read -r line; do
  MSG="${line%|||*}"
  HASH="${line##*|||}"
  SHORT_HASH="${HASH:0:7}"

  # Check for breaking changes
  if echo "$MSG" | grep -qE '^[a-z]+(\(.+\))?!:|BREAKING CHANGE'; then
    BUMP="major"
    CLEAN_MSG=$(echo "$MSG" | sed -E 's/^[a-z]+(\(.+\))?!: //')
    BREAKING="${BREAKING}\n- ${CLEAN_MSG} (${SHORT_HASH})"
    continue
  fi

  # Extract type
  TYPE=$(echo "$MSG" | sed -nE 's/^([a-z]+)(\(.+\))?: .*/\1/p')
  CLEAN_MSG=$(echo "$MSG" | sed -E 's/^[a-z]+(\(.+\))?: //')

  case "$TYPE" in
    feat)
      [ "$BUMP" != "major" ] && BUMP="minor"
      FEATS="${FEATS}\n- ${CLEAN_MSG} (${SHORT_HASH})"
      ;;
    fix)
      [ "$BUMP" = "none" ] && BUMP="patch"
      FIXES="${FIXES}\n- ${CLEAN_MSG} (${SHORT_HASH})"
      ;;
    docs)
      DOCS="${DOCS}\n- ${CLEAN_MSG} (${SHORT_HASH})"
      ;;
    chore|ci|build|refactor|style|test|perf)
      CHORES="${CHORES}\n- ${CLEAN_MSG} (${SHORT_HASH})"
      ;;
    *)
      OTHER="${OTHER}\n- ${MSG} (${SHORT_HASH})"
      ;;
  esac
done <<< "$COMMITS"

# Apply version bump
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  none)
    echo "No version-bumping commits found."
    NEW_VERSION="$CURRENT_VERSION"
    RELEASE_NOTES=""
    return 0 2>/dev/null || exit 0
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "Version bump: ${CURRENT_VERSION} → ${NEW_VERSION} (${BUMP})"

# Build release notes
RELEASE_NOTES="## What's Changed\n"

if [ -n "$BREAKING" ]; then
  RELEASE_NOTES="${RELEASE_NOTES}\n### ⚠️ Breaking Changes\n${BREAKING}\n"
fi
if [ -n "$FEATS" ]; then
  RELEASE_NOTES="${RELEASE_NOTES}\n### ✨ Features\n${FEATS}\n"
fi
if [ -n "$FIXES" ]; then
  RELEASE_NOTES="${RELEASE_NOTES}\n### 🐛 Bug Fixes\n${FIXES}\n"
fi
if [ -n "$DOCS" ]; then
  RELEASE_NOTES="${RELEASE_NOTES}\n### 📚 Documentation\n${DOCS}\n"
fi
if [ -n "$CHORES" ]; then
  RELEASE_NOTES="${RELEASE_NOTES}\n### 🔧 Maintenance\n${CHORES}\n"
fi
if [ -n "$OTHER" ]; then
  RELEASE_NOTES="${RELEASE_NOTES}\n### Other\n${OTHER}\n"
fi

RELEASE_NOTES="${RELEASE_NOTES}\n**Full Changelog**: https://github.com/\${GITHUB_REPOSITORY:-agentmurph/Whispr}/compare/${LATEST_TAG}...v${NEW_VERSION}"

export CURRENT_VERSION NEW_VERSION BUMP RELEASE_NOTES
