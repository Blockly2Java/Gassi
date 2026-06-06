#!/usr/bin/env bash
# Clones sibling repos (template, solution, tests) alongside parent/ for local development.
# Run once after cloning the parent repo into a new folder.
# Self-discovering: derives org and exercise name from git remote — no editing needed.
#
# Usage:
#   mkdir MyExercise && cd MyExercise
#   git clone git@github.com:Org/MyExercise_parent.git parent
#   cd parent && ./local-setup.sh
#
# Result:
#   MyExercise/
#   ├── parent/       ← Git repo (MyExercise_parent)
#   ├── template/     ← Git repo (MyExercise_template)
#   ├── solution/     ← Git repo (MyExercise_solution)
#   └── tests/        ← Git repo (MyExercise_tests)

set -e

# Derive org and exercise name from the git remote of THIS repo (parent)
REMOTE_URL=$(git remote get-url origin)
# Handles both SSH (git@github.com:Org/Repo.git) and HTTPS (https://github.com/Org/Repo.git)
ORG=$(echo "$REMOTE_URL" | sed -E 's|.*[:/]([^/]+)/[^/]+\.git.*|\1|')
EXERCISE=$(echo "$REMOTE_URL" | sed -E 's|.*[:/][^/]+/([^/]+)\.git.*|\1|')

echo "Organisation : $ORG"
echo "Exercise     : $EXERCISE"
echo ""

BASE="git@github.com:${ORG}"

# Clone sibling repos into the directory ABOVE parent/ (siblings of parent/)
PARENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for sub in template solution tests; do
  SUB_DIR="$PARENT_DIR/$sub"
  if [ ! -d "$SUB_DIR/.git" ]; then
    echo "Cloning ${EXERCISE}_${sub}..."
    git clone "${BASE}/${EXERCISE}_${sub}.git" "$SUB_DIR"
  else
    echo "$sub already present, pulling latest..."
    git -C "$SUB_DIR" pull --ff-only
  fi
done

echo ""
echo "Done! Structure:"
echo "  $PARENT_DIR/"
echo "  ├── parent/       (this repo)"
echo "  ├── template/     (student code)"
echo "  ├── solution/     (reference solution)"
echo "  └── tests/        (test harness)"
echo ""
echo "Run 'cd $PARENT_DIR && gradle testSolution' to verify."