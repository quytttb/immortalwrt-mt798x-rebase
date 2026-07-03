#!/bin/bash
# Sync fork main with upstream chasey-dev/25.12
# Usage: ./scripts/sync-upstream.sh [remote] [branch]
#   remote: upstream remote name (default: origin)
#   branch: upstream branch (default: 25.12)
#
# Prerequisites:
#   - .gitattributes has merge=ours for fork-owned files (DTS, LED helper
#     scripts, migration hook, README, sync helper)
#   - Shared files such as target/linux/mediatek/filogic/base-files/etc/board.d/01_leds
#     are intentionally not protected and must be reviewed when upstream touches them
#   - Run this script from the repo root on the fork's main branch

set -e

REMOTE="${1:-origin}"
BRANCH="${2:-25.12}"

echo "Registering merge=ours driver..."
git config merge.ours.driver true

echo "Fetching ${REMOTE}/${BRANCH}..."
git fetch "${REMOTE}" "${BRANCH}"

UPSTREAM_SHA=$(git rev-parse --short "${REMOTE}/${BRANCH}")
echo "Merging ${REMOTE}/${BRANCH} (${UPSTREAM_SHA})..."

git merge "${REMOTE}/${BRANCH}" \
  -m "chore: sync upstream ${BRANCH} (${UPSTREAM_SHA})"

# Sanity check: should be no unresolved conflicts
if git diff --name-only --diff-filter=U | grep -q .; then
  echo ""
  echo "ERROR: Conflicts remain in the following files:"
  git diff --name-only --diff-filter=U
  echo ""
  echo "Resolve manually, then run: git add -A && git commit --no-edit"
  exit 1
fi

echo ""
echo "Sync complete. Protected files (merge=ours):"
grep "merge=ours" .gitattributes 2>/dev/null || echo "  (none configured)"

echo ""
echo "Review shared Viettel LED files if they changed in this merge:"
echo "  - target/linux/mediatek/filogic/base-files/etc/board.d/01_leds"

echo ""
echo "To push: git push quytttb main"
