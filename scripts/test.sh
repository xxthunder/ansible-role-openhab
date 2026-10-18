#!/usr/bin/env bash
# The single entry point for the role's checks — the same run locally and in CI.
#
# Needs uv and a Docker daemon the current user can reach. Everything else
# (ansible-core, ansible-lint, yamllint, Molecule) comes from uv.lock, and the
# collections from requirements.yml.
#
# Usage: scripts/test.sh          lint, then every Molecule scenario
#        scripts/test.sh lint     lint only
set -euo pipefail

cd "$(dirname "$0")/.."

uv sync --frozen

# Collections go into the checkout, not the user's ~/.ansible: the run then sees
# exactly the versions requirements.yml pins, whatever else the machine has
# installed, and leaves other projects' collections alone.
export ANSIBLE_COLLECTIONS_PATH="$PWD/.ansible/collections"
uv run ansible-galaxy collection install --force -r requirements.yml

echo "== yamllint"
uv run yamllint -c .yamllint .

echo "== ansible-lint"
uv run ansible-lint

if [ "${1:-}" = "lint" ]; then
  exit 0
fi

for scenario in molecule/*/; do
  scenario=$(basename "$scenario")
  echo "== molecule test -s $scenario"
  uv run molecule test -s "$scenario"
done
