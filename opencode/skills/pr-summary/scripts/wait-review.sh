#!/usr/bin/env bash
# Wait for the Codex review of the latest push on a pull request and print it.
# Only for repositories of the Merlin-Digital-Solutions organization: the
# review comes from the codex-review.yml workflow, which posts a comment that
# starts with "<!-- codex-review -->".
#
# Usage: bash wait-review.sh [PR-NUMBER] [MAX-MINUTES]
#   PR-NUMBER    defaults to the pull request of the current branch
#   MAX-MINUTES  defaults to 30
# Exit 0 and the review on stdout; exit 1 when no review came in time.
set -euo pipefail

pr=${1:-$(gh pr view --json number --jq .number)}
max=${2:-30}
head=$(gh pr view "$pr" --json headRefOid --jq .headRefOid)
pushed=$(gh api "repos/{owner}/{repo}/commits/$head" --jq .commit.committer.date)

for ((minute = 0; minute < max; minute++)); do
  review=$(gh pr view "$pr" --json comments | jq -r --arg pushed "$pushed" '
    [.comments[]
     | select(.createdAt > $pushed and (.body | startswith("<!-- codex-review -->")))]
    | last | .body // empty')
  if [[ -n $review ]]; then
    printf '%s\n' "$review"
    exit 0
  fi
  sleep 60
done

echo "No Codex review of the latest push (committed $pushed) after $max minutes." >&2
exit 1
