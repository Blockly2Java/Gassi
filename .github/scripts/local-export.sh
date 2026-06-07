#!/bin/bash
#
# Local export script for generating Artemis exercise packages.
#
# This script creates a fully isolated staging environment that mirrors
# exactly what GitHub Actions does. It clones all repos from GitHub,
# runs the same Python scripts, and creates the same ZIP structure.
#
# Usage:
#   ./parent/.github/scripts/local-export.sh \
#     --title "Gassi Migration" \
#     --short-name "gassimigration" \
#     --id "20534" \
#     --course-prefix "testmtgherrmann" \
#     --github-repo "youruser/Gassi" \
#     --branch "main"
#
# Options:
#   --keep-temp          Keep the staging directory for debugging
#   --github-token TOKEN GitHub token for private repos (uses GH_TOKEN env var if not provided)

set -euo pipefail

# -------------------------------------------------------------------
# Parse arguments
# -------------------------------------------------------------------
TITLE=""
SHORT_NAME=""
EXERCISE_ID=""
COURSE_PREFIX=""
GITHUB_REPO=""
BRANCH="main"
KEEP_TEMP=false
GITHUB_TOKEN="${GH_TOKEN:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --title) TITLE="$2"; shift 2 ;;
        --short-name) SHORT_NAME="$2"; shift 2 ;;
        --id) EXERCISE_ID="$2"; shift 2 ;;
        --course-prefix) COURSE_PREFIX="$2"; shift 2 ;;
        --github-repo) GITHUB_REPO="$2"; shift 2 ;;
        --branch) BRANCH="$2"; shift 2 ;;
        --keep-temp) KEEP_TEMP=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Validate required arguments
if [[ -z "$TITLE" || -z "$SHORT_NAME" || -z "$EXERCISE_ID" || -z "$COURSE_PREFIX" || -z "$GITHUB_REPO" ]]; then
    echo "Usage: $0 --title TITLE --short-name NAME --id ID --course-prefix PREFIX --github-repo REPO [--branch BRANCH] [--keep-temp]"
    exit 1
fi

# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="$(pwd)"

# -------------------------------------------------------------------
# Create isolated staging directory
# -------------------------------------------------------------------
STAGING_DIR=$(mktemp -d "/tmp/artemis-export-staging-XXXXXX")
echo "=== Creating isolated staging environment: $STAGING_DIR ==="

# -------------------------------------------------------------------
# Clone repositories (same as GitHub Actions checkout steps)
# -------------------------------------------------------------------
echo ""
echo "=== Cloning repositories ==="

# Clone parent repo (contains scripts)
echo "Cloning parent repo: $GITHUB_REPO ..."
gh repo clone "$GITHUB_REPO" "$STAGING_DIR/parent" -- --branch "$BRANCH" -- 2>/dev/null || \
git clone --branch "$BRANCH" "https://github.com/$GITHUB_REPO.git" "$STAGING_DIR/parent"

# Clone template repo
TEMPLATE_REPO="${GITHUB_REPO%/*}/${SHORT_NAME}-template"
if [ "$TEMPLATE_REPO" = "$GITHUB_REPO" ]; then
    # Fallback: use same repo if template repo doesn't exist pattern
    echo "Skipping template repo (name pattern not matched): $TEMPLATE_REPO"
else
    echo "Cloning template repo: $TEMPLATE_REPO ..."
    gh repo clone "$TEMPLATE_REPO" "$STAGING_DIR/template" -- --branch "$BRANCH" -- 2>/dev/null || \
    git clone --branch "$BRANCH" "https://github.com/$TEMPLATE_REPO.git" "$STAGING_DIR/template" 2>/dev/null || \
    echo "WARNING: Could not clone template repo: $TEMPLATE_REPO"
fi

# Clone solution repo
SOLUTION_REPO="${GITHUB_REPO%/*}/${SHORT_NAME}-solution"
echo "Cloning solution repo: $SOLUTION_REPO ..."
gh repo clone "$SOLUTION_REPO" "$STAGING_DIR/solution" -- --branch "$BRANCH" -- 2>/dev/null || \
git clone --branch "$BRANCH" "https://github.com/$SOLUTION_REPO.git" "$STAGING_DIR/solution" 2>/dev/null || \
echo "WARNING: Could not clone solution repo: $SOLUTION_REPO"

# Clone tests repo
TESTS_REPO="${GITHUB_REPO%/*}/${SHORT_NAME}-tests"
echo "Cloning tests repo: $TESTS_REPO ..."
gh repo clone "$TESTS_REPO" "$STAGING_DIR/tests" -- --branch "$BRANCH" -- 2>/dev/null || \
git clone --branch "$BRANCH" "https://github.com/$TESTS_REPO.git" "$STAGING_DIR/tests" 2>/dev/null || \
echo "WARNING: Could not clone tests repo: $TESTS_REPO"

# -------------------------------------------------------------------
# Generate Exercise-Details JSON
# -------------------------------------------------------------------
echo ""
echo "=== Generating Exercise-Details JSON ==="
cd "$STAGING_DIR"
python3 "$SCRIPT_DIR/generate-exercise-details.py" \
    --title "$TITLE" \
    --short-name "$SHORT_NAME" \
    --id "$EXERCISE_ID" \
    --course-prefix "$COURSE_PREFIX" \
    --template-file "$SCRIPT_DIR/exercise-details-template.json" \
    --output "Exercise-Details-${SHORT_NAME}.json"

# -------------------------------------------------------------------
# Generate Problem Statement Markdown
# -------------------------------------------------------------------
echo ""
echo "=== Generating Problem Statement Markdown ==="
python3 "$SCRIPT_DIR/generate-problem-statement.py" \
    --source template/README.md \
    --output "Problem-Statement-${SHORT_NAME}.md"

# -------------------------------------------------------------------
# Create ZIP packages using shared export-core.py
# -------------------------------------------------------------------
echo ""
echo "=== Creating ZIP packages ==="
python3 "$SCRIPT_DIR/export-core.py" create-zips \
    --short-name "$SHORT_NAME" \
    --template-dir template \
    --solution-dir solution \
    --tests-dir tests \
    --output-dir .

# -------------------------------------------------------------------
# Package final export ZIP
# -------------------------------------------------------------------
echo ""
echo "=== Packaging final export ZIP ==="
EXPORT_ZIP=$(python3 "$SCRIPT_DIR/export-core.py" package-export \
    --short-name "$SHORT_NAME" \
    --id "$EXERCISE_ID" \
    --course-prefix "$COURSE_PREFIX" \
    --output-dir .)

# -------------------------------------------------------------------
# Copy to base directory and cleanup
# -------------------------------------------------------------------
echo ""
echo "=== Copying export to: $BASE_DIR ==="
cp "$EXPORT_ZIP" "$BASE_DIR/"

FINAL_PATH="$BASE_DIR/$(basename "$EXPORT_ZIP")"
echo ""
echo "========================================"
echo "Export completed successfully!"
echo "Location: $FINAL_PATH"
echo "========================================"

# -------------------------------------------------------------------
# Cleanup or keep staging
# -------------------------------------------------------------------
if [[ "$KEEP_TEMP" == "true" ]]; then
    echo ""
    echo "Staging directory preserved for debugging: $STAGING_DIR"
else
    echo ""
    echo "Cleaning up staging directory..."
    rm -rf "$STAGING_DIR"
    echo "Done."
fi