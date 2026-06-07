#!/usr/bin/env bash
# Local test script for Artemis exercise export.
#
# This script mimics the GitHub Actions workflow by:
# 1. Creating a temporary staging directory
# 2. Copying the exercise repos (parent, template, solution, tests) from local
# 3. Generating the exercise details JSON
# 4. Generating the problem statement Markdown
# 5. Creating the exercise, solution, and tests ZIPs
# 6. Packaging everything into the final export ZIP
# 7. Cleaning up the temporary directory (unless --keep-temp is passed)
#
# Usage:
#   ./local-export.sh \
#     --title "My Exercise" \
#     --short-name "myexercise" \
#     --id "12345" \
#     --course-prefix "course101" \
#     --github-repo "myorg/myrepo"
#
# Options:
#   --title           Exercise title (required)
#   --short-name      Short name for the exercise (required)
#   --id              Exercise ID number (required)
#   --course-prefix   Course prefix (required)
#   --github-repo     GitHub repository in "owner/name" format (required)
#   --keep-temp       Keep the temporary directory for debugging
#   --help            Show this help message

set -euo pipefail

# Default values
TITLE=""
SHORT_NAME=""
ID=""
COURSE_PREFIX=""
GITHUB_REPO=""
KEEP_TEMP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --title) TITLE="$2"; shift 2 ;;
        --short-name) SHORT_NAME="$2"; shift 2 ;;
        --id) ID="$2"; shift 2 ;;
        --course-prefix) COURSE_PREFIX="$2"; shift 2 ;;
        --github-repo) GITHUB_REPO="$2"; shift 2 ;;
        --keep-temp) KEEP_TEMP=true; shift ;;
        --help)
            echo "Usage: $0 --title TITLE --short-name SHORT_NAME --id ID --course-prefix PREFIX --github-repo REPO [--keep-temp] [--help]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Validate required arguments
if [[ -z "$TITLE" || -z "$SHORT_NAME" || -z "$ID" || -z "$COURSE_PREFIX" || -z "$GITHUB_REPO" ]]; then
    echo "Error: All of --title, --short-name, --id, --course-prefix, and --github-repo are required."
    exit 1
fi

# Extract owner and repo from GITHUB_REPO
OWNER="${GITHUB_REPO%%/*}"
REPO_NAME="${GITHUB_REPO#*/}"

if [[ "$OWNER" == "$GITHUB_REPO" || -z "$OWNER" || -z "$REPO_NAME" ]]; then
    echo "Error: --github-repo must be in 'owner/name' format (e.g., myorg/myrepo)."
    exit 1
fi

# Create a temporary staging directory
STAGING_DIR=$(mktemp -d)
echo "Created staging directory: $STAGING_DIR"

# Cleanup function
cleanup() {
    if [[ "$KEEP_TEMP" == "false" ]]; then
        echo "Cleaning up temporary directory: $STAGING_DIR"
        rm -rf "$STAGING_DIR"
    else
        echo "Keeping temporary directory for debugging: $STAGING_DIR"
    fi
}
trap cleanup EXIT

# Get the directory where this script resides
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy local repos to staging directory
echo "Copying local repos to staging directory..."
# Parent directory is one level up from SCRIPT_DIR
cp -r "$SCRIPT_DIR/../.." "$STAGING_DIR/parent"
# Template, solution, tests directories are in the workspace root
WORKSPACE_DIR="$SCRIPT_DIR/../../.."
cp -r "$WORKSPACE_DIR/template" "$STAGING_DIR/template"
cp -r "$WORKSPACE_DIR/solution" "$STAGING_DIR/solution"
cp -r "$WORKSPACE_DIR/tests" "$STAGING_DIR/tests"

# Copy scripts and templates to staging directory
cp "$SCRIPT_DIR/generate-exercise-details.py" "$STAGING_DIR/"
cp "$SCRIPT_DIR/generate-problem-statement.py" "$STAGING_DIR/"
cp "$SCRIPT_DIR/export-core.py" "$STAGING_DIR/"
cp "$SCRIPT_DIR/exercise-details-template.json" "$STAGING_DIR/"

# Run generate-exercise-details.py
echo "Generating exercise details JSON..."
python3 "$STAGING_DIR/generate-exercise-details.py" \
    --template "$STAGING_DIR/exercise-details-template.json" \
    --title "$TITLE" \
    --short-name "$SHORT_NAME" \
    --id "$ID" \
    --course-prefix "$COURSE_PREFIX" \
    --output "$STAGING_DIR/Exercise-Details-${SHORT_NAME}.json"

# Run generate-problem-statement.py
echo "Generating problem statement Markdown..."
python3 "$STAGING_DIR/generate-problem-statement.py" \
    --input "$STAGING_DIR/template/README.md" \
    --title "$TITLE" \
    --short-name "$SHORT_NAME" \
    --id "$ID" \
    --course-prefix "$COURSE_PREFIX" \
    --output "$STAGING_DIR/Problem-Statement-${SHORT_NAME}.md"

# Run export-core.py create-zips
echo "Creating exercise, solution, and tests ZIPs..."
python3 "$STAGING_DIR/export-core.py" create-zips \
    --short-name "$SHORT_NAME" \
    --parent-dir "$STAGING_DIR/parent" \
    --template-dir "$STAGING_DIR/template" \
    --solution-dir "$STAGING_DIR/solution" \
    --tests-dir "$STAGING_DIR/tests" \
    --output-dir "$STAGING_DIR"

# Run export-core.py package-export
echo "Packaging final export ZIP..."
python3 "$STAGING_DIR/export-core.py" package-export \
    --short-name "$SHORT_NAME" \
    --id "$ID" \
    --course-prefix "$COURSE_PREFIX" \
    --parent-dir "$STAGING_DIR/parent" \
    --json-file "$STAGING_DIR/Exercise-Details-${SHORT_NAME}.json" \
    --md-file "$STAGING_DIR/Problem-Statement-${SHORT_NAME}.md" \
    --exercise-zip "$STAGING_DIR/${SHORT_NAME}-exercise.zip" \
    --solution-zip "$STAGING_DIR/${SHORT_NAME}-solution.zip" \
    --tests-zip "$STAGING_DIR/${SHORT_NAME}-tests.zip" \
    --output-dir "."

echo "Export ZIP created in current directory."
echo "Done!"
