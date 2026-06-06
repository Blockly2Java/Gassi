# Artemis Export Scripts

This directory contains scripts for generating Artemis exercise export packages from the repository.

## Overview

The scripts automate the creation of Artemis-compatible exercise packages that can be imported into the Artemis learning management system. The export process generates:

1. **Exercise-Details JSON** - Artemis configuration file with exercise metadata
2. **Problem Statement Markdown** - Student-facing exercise description
3. **Three repository ZIPs** - Exercise (template), solution, and tests repositories
4. **Final export ZIP** - All components packaged for import

## Scripts

### `generate-exercise-details.py`

Generates the Artemis exercise details JSON configuration file.

**Usage:**
```bash
python3 generate-exercise-details.py \
    --title "Exercise Title" \
    --short-name "exercisetitle" \
    --id "12345" \
    --course-prefix "testmtgherrmann" \
    --max-points "10.0" \
    --package-name "b2j.test" \
    --template-file exercise-details-template.json \
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
python3 generate-problem-statement.py \
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
- `{{THEIA_IMAGE}}` - Theia IDE image

## Workflow Integration

These scripts are primarily used by the GitHub Actions workflow `.github/workflows/generate-artemis-export.yml`. The workflow:

1. Checks out the parent (scripts), template, solution, and tests repositories
2. Generates the exercise details JSON using the template
3. Generates the problem statement from the template's README
4. Creates ZIP files for template (exercise), solution, and tests repositories (excluding git object data)
5. Packages everything into a final Artemis export ZIP
6. Uploads the export as a workflow artifact

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
