# Artemis Export Scripts

This directory contains scripts for generating Artemis exercise export packages from the repository.

## Overview

The scripts automate the creation of Artemis-compatible exercise packages that can be imported into the Artemis learning management system. The export process generates:

1. **Exercise-Details JSON** - Artemis configuration file with exercise metadata
2. **Problem Statement Markdown** - Student-facing exercise description
3. **Three repository ZIPs** - Exercise (template), solution, and tests repositories
4. **Final export ZIP** - All components packaged for import

## Architecture

All export logic is shared between the GitHub Actions workflow and local testing via a core module:

```
┌─────────────────────────────────────────────────────┐
│                   GitHub Actions                     │
│                                                       │
│  checkout → Python scripts → export-core.py → ZIP   │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                   Local Testing                      │
│                                                       │
│  local-export.sh → Python scripts → export-core.py   │
│  → clones repos → creates ZIPs                       │
└─────────────────────────────────────────────────────┘
```

**Shared components:**
- `generate-exercise-details.py` - JSON generation (100% shared)
- `generate-problem-statement.py` - Markdown generation (100% shared)
- `export-core.py` - ZIP creation and packaging (100% shared)

**Differences only:**
- GitHub Actions: uses `actions/checkout@v4` for repo cloning
- Local: `local-export.sh` clones repos via `git clone`

## Files

| File | Purpose |
|------|---------|
| `generate-exercise-details.py` | Generates Artemis JSON configuration |
| `generate-problem-statement.py` | Generates problem statement Markdown |
| `export-core.py` | Shared ZIP creation and packaging logic |
| `local-export.sh` | Local testing entry point |
| `exercise-details-template.json` | Template with placeholder values |
| `README.md` | This file |

## Scripts

### `generate-exercise-details.py`

Generates the Artemis exercise details JSON configuration file.

**Usage:**
```bash
python3 parent/.github/scripts/generate-exercise-details.py \
    --title "Exercise Title" \
    --short-name "exercisetitle" \
    --id "12345" \
    --course-prefix "testmtgherrmann" \
    --max-points "10.0" \
    --template-file parent/.github/scripts/exercise-details-template.json \
    --output Exercise-Details.json
```

**Parameters:**
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--title` | Yes | - | Exercise title |
| `--short-name` | Yes | - | Short name (lowercase, no spaces) |
| `--id` | Yes | - | Artemis Exercise ID |
| `--course-prefix` | Yes | - | Course/username prefix |
| `--output` | Yes | - | Output file path |
| `--max-points` | No | `10.0` | Maximum points |
| `--package-name` | No | `b2j.test` | Java package name |
| `--docker-image` | No | `ghcr.io/valentinherrmann/artemis-maven-docker:latest` | Docker image for building |
| `--build-script` | No | `chmod +x gradlew\n./gradlew clean test` | Build script commands |
| `--theia-image` | No | `java-17-latest` | Theia IDE image |
| `--template-file` | No | None | Path to template JSON file |

### `generate-problem-statement.py`

Generates the problem statement Markdown file from the template README.

**Usage:**
```bash
python3 parent/.github/scripts/generate-problem-statement.py \
    --source template/README.md \
    --output Problem-Statement.md
```

**Parameters:**
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--source` | Yes | - | Source README.md path |
| `--output` | Yes | - | Output file path |
| `--shared-resources-url` | No | None | Base URL for shared resources |
| `--validate` | No | false | Validate and print warnings |

### `export-core.py`

Shared module for creating ZIP files from repository directories and packaging them into the final export ZIP.

**Commands:**

#### `create-zips`
Creates ZIP files for template (exercise), solution, and tests repositories.

```bash
python3 parent/.github/scripts/export-core.py create-zips \
    --short-name "gassi" \
    --template-dir template \
    --solution-dir solution \
    --tests-dir tests \
    --output-dir .
```

#### `package-export`
Packages all components into the final Artemis export ZIP.

```bash
python3 parent/.github/scripts/export-core.py package-export \
    --short-name "gassi" \
    --id "20534" \
    --course-prefix "testmtgherrmann" \
    --output-dir .
```

### `local-export.sh`

Fully isolated local testing script that mirrors GitHub Actions exactly. Creates a temporary staging directory, clones all repos from GitHub, runs the same Python scripts, and creates the same ZIP structure.

**Usage:**
```bash
./parent/.github/scripts/local-export.sh \
    --title "Gassi Migration" \
    --short-name "gassimigration" \
    --id "20534" \
    --course-prefix "testmtgherrmann" \
    --github-repo "youruser/Gassi" \
    --branch "main"
```

**Parameters:**
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--title` | Yes | - | Exercise title |
| `--short-name` | Yes | - | Short name (lowercase, no spaces) |
| `--id` | Yes | - | Artemis Exercise ID |
| `--course-prefix` | Yes | - | Course/username prefix |
| `--github-repo` | Yes | - | GitHub repo in format `owner/repo` |
| `--branch` | No | `main` | Branch to checkout |
| `--keep-temp` | No | false | Keep staging directory for debugging |

**Example with debug mode:**
```bash
./parent/.github/scripts/local-export.sh \
    --title "Gassi Migration" \
    --short-name "gassimigration" \
    --id "20534" \
    --course-prefix "testmtgherrmann" \
    --github-repo "youruser/Gassi" \
    --keep-temp
```

## Template

The `exercise-details-template.json` file contains a template with placeholder values that get substituted during generation.

**Available Placeholders:**
- `{{ID}}` - Exercise ID
- `{{TITLE}}` - Exercise title
- `{{SHORT_NAME}}` - Short name (lowercase, no spaces)
- `{{MAX_POINTS}}` - Maximum points
- `{{COURSE_PREFIX}}` - Course prefix
- `{{PACKAGE_NAME}}` - Java package name
- `{{BUILD_PLAN_CONFIG}}` - Build configuration JSON

## GitHub Actions Workflow

The workflow `.github/workflows/generate-artemis-export.yml` can be triggered manually:

1. Go to Actions → "Generate Artemis Export" → "Run workflow"
2. Fill in the exercise details
3. The workflow produces a ZIP file as an artifact

**Workflow Steps:**
1. Checkout parent repo (contains scripts)
2. Checkout template, solution, and tests repos
3. Generate exercise details JSON
4. Generate problem statement Markdown
5. Create ZIP packages using `export-core.py`
6. Package final export ZIP using `export-core.py`
7. Upload as workflow artifact

## Output Format

The final export ZIP follows this naming convention:
```
{course_prefix}-{short_name}-{id}-{YYYYMMDD}-{HHMMSS}.zip
```

Example: `testmtgherrmann-Gassi_Migration-20534-20260606-232417.zip`

Inside the export ZIP:
```
├── Exercise-Details-{short_name}.json
├── Problem-Statement-{short_name}.md
├── {short_name}-exercise.zip      ← from {short_name}-template repo
├── {short_name}-solution.zip      ← from {short_name}-solution repo
└── {short_name}-tests.zip         ← from {short_name}-tests repo
```

Each sub-ZIP contains the full contents of its respective repository.

## Repository Structure

This system expects the following GitHub repositories:

| Repository | Purpose |
|------------|---------|
| `{exercise_name}` (parent) | Contains the workflow and scripts for export |
| `{exercise_name}-template` | Student-facing stub code (becomes exercise ZIP) |
| `{exercise_name}-solution` | Reference solution (becomes solution ZIP) |
| `{exercise_name}-tests` | Test harness (becomes tests ZIP) |

The **template** repository is the source for the exercise ZIP - it contains the stub code that students receive, with empty method bodies to implement.

## Local Testing (Fully Isolated)

To test the export process locally with the same behavior as GitHub Actions:

```bash
# Ensure you're in the workspace root directory
cd /path/to/your/workspace

# Run the local export script
./parent/.github/scripts/local-export.sh \
    --title "My Exercise" \
    --short-name "myexercise" \
    --id "12345" \
    --course-prefix "testmtgherrmann" \
    --github-repo "yourorg/MyExercise"
```

This will:
1. Create a temporary directory
2. Clone all repos fresh from GitHub
3. Run the exact same Python scripts as the workflow
4. Create the same ZIP structure
5. Output the final export ZIP to the current directory
6. Clean up the temporary directory

Use `--keep-temp` to inspect the staging directory if something goes wrong.