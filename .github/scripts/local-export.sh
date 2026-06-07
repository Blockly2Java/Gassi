#!/usr/bin/env bash
set -euo pipefail

TITLE="Gassi"
SHORT_NAME="gassi"
ID="1"
COURSE_PREFIX="testmtgherrmann"
GITHUB_REPO="Blockly2Java/Gassi"
KEEP_TEMP=false

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

if [[ -z "$TITLE" || -z "$SHORT_NAME" || -z "$ID" || -z "$COURSE_PREFIX" || -z "$GITHUB_REPO" ]]; then
    echo "Error: All of --title, --short-name, --id, --course-prefix, and --github-repo are required."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

STAGING_DIR=$(mktemp -d)
echo "Created staging directory: $STAGING_DIR"

cleanup() {
    if [[ "$KEEP_TEMP" == "false" ]]; then
        if ls "$STAGING_DIR"/*.zip 1>/dev/null 2>&1; then
            mkdir -p "$WORKSPACE_DIR/Artemis_Export"
            cp "$STAGING_DIR"/*.zip "$WORKSPACE_DIR/Artemis_Export/"
            echo "Copied export ZIP to Artemis_Export directory: $WORKSPACE_DIR/Artemis_Export"
        fi
        echo "Cleaning up temporary directory: $STAGING_DIR"
        rm -rf "$STAGING_DIR"
    else
        echo "Keeping temporary directory for debugging: $STAGING_DIR"
    fi
}
trap cleanup EXIT

echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "PARENT_DIR: $PARENT_DIR"
echo "WORKSPACE_DIR: $WORKSPACE_DIR"

echo "Copying local repos to staging directory..."
cp -r "$PARENT_DIR" "$STAGING_DIR/parent"
cp -r "$WORKSPACE_DIR/template" "$STAGING_DIR/template"
cp -r "$WORKSPACE_DIR/solution" "$STAGING_DIR/solution"
cp -r "$WORKSPACE_DIR/parent" "$STAGING_DIR/tests" # Do not change this path. I know it's not intuitive, but what we need here!!!

cp "$SCRIPT_DIR/generate-exercise-details.py" "$STAGING_DIR/"
cp "$SCRIPT_DIR/generate-problem-statement.py" "$STAGING_DIR/"
cp "$SCRIPT_DIR/export-core.py" "$STAGING_DIR/"
cp "$SCRIPT_DIR/exercise-details-template.json" "$STAGING_DIR/"

echo "Generating exercise details JSON..."
python3 "$STAGING_DIR/generate-exercise-details.py" \
    --template-file "$STAGING_DIR/exercise-details-template.json" \
    --title "$TITLE" \
    --short-name "$SHORT_NAME" \
    --id "$ID" \
    --course-prefix "$COURSE_PREFIX" \
    --output "$STAGING_DIR/Exercise-Details-${SHORT_NAME}.json"

echo "Generating problem statement Markdown..."
python3 "$STAGING_DIR/generate-problem-statement.py" \
    --source "$STAGING_DIR/template/README.md" \
    --output "$STAGING_DIR/Problem-Statement-${SHORT_NAME}.md"

echo "Creating exercise, solution, and tests ZIPs..."
python3 "$STAGING_DIR/export-core.py" create-zips \
    --short-name "$SHORT_NAME" \
    --template-dir "$STAGING_DIR/template" \
    --solution-dir "$STAGING_DIR/solution" \
    --tests-dir "$STAGING_DIR/tests" \
    --output-dir "$STAGING_DIR"

echo "Packaging final export ZIP..."
python3 "$STAGING_DIR/export-core.py" package-export \
    --short-name "$SHORT_NAME" \
    --id "$ID" \
    --course-prefix "$COURSE_PREFIX" \
    --json-file "$STAGING_DIR/Exercise-Details-${SHORT_NAME}.json" \
    --md-file "$STAGING_DIR/Problem-Statement-${SHORT_NAME}.md" \
    --output-dir "$STAGING_DIR"

echo "Export ZIP created in staging directory."
ls -la "$STAGING_DIR"/*.zip

echo "Done!"
