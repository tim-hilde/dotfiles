#!/usr/bin/env bash
# Wait for the Codex review of the current head of a pull request and print it.
# Only for repositories of the Merlin-Digital-Solutions organization: the
# review comes from the codex-review.yml workflow, which posts a comment that
# starts with "<!-- codex-review -->".
#
# Usage: bash wait-review.sh [PR-NUMBER] [MAX-MINUTES] [SHA]
#   PR-NUMBER    defaults to the pull request of the current branch
#   MAX-MINUTES  defaults to 30
#   SHA          the commit you pushed. Defaults to the local HEAD when the
#                current branch is the head branch of the PR. The script waits
#                until the PR head is this commit or a later one (for example a
#                commit of the migration bot), so it never returns the review
#                of the push before.
# Exit 0: the review of the current head is on stdout.
# Exit 1: no review came in time.
# Exit 2: the PR is a draft. codex-review.yml skips drafts, so no review comes.
set -euo pipefail

pr=${1:-$(gh pr view --json number --jq .number)}
max=${2:-30}
expected=${3:-}
marker='<!-- codex-review -->'

if [[ -z $expected ]]; then
  branch=$(git branch --show-current 2>/dev/null || true)
  if [[ -n $branch && $branch == "$(gh pr view "$pr" --json headRefName --jq .headRefName)" ]]; then
    expected=$(git rev-parse HEAD)
  fi
fi

# True when the PR head is the expected commit or a commit after it.
head_has_expected() {
  [[ -z $expected || $1 == "$expected" ]] && return 0
  [[ $(gh api "repos/{owner}/{repo}/compare/$expected...$1" --jq .status 2>/dev/null || true) == ahead ]]
}

# The id of the newest review comment that is younger than the head commit
# and younger than the newest codex-review.yml run for the head. The run
# matters when one commit gets several runs, for example a skipped run while
# the PR was a draft and a second run after "gh pr ready".
review_of() {
  local since run
  since=$(gh api "repos/{owner}/{repo}/commits/$1" --jq .commit.committer.date)
  run=$(gh api "repos/{owner}/{repo}/actions/workflows/codex-review.yml/runs?head_sha=$1&per_page=100" \
    --jq '[.workflow_runs[].created_at] | max // empty' 2>/dev/null || true)
  [[ -n $run && $run > $since ]] && since=$run
  gh api --paginate "repos/{owner}/{repo}/issues/$pr/comments?per_page=100" \
    --jq ".[] | select(.created_at > \"$since\" and (.body | startswith(\"$marker\"))) | .id" | tail -n 1
}

for ((minute = 0; minute < max; minute++)); do
  read -r head draft < <(gh pr view "$pr" --json headRefOid,isDraft --jq '"\(.headRefOid) \(.isDraft)"')
  if head_has_expected "$head"; then
    id=$(review_of "$head")
    if [[ -n $id ]]; then
      echo "Codex review of $head (comment $id):" >&2
      gh api "repos/{owner}/{repo}/issues/comments/$id" --jq .body
      exit 0
    fi
    if [[ $draft == true ]]; then
      echo "PR #$pr is a draft, and codex-review.yml skips drafts. Run 'gh pr ready $pr', then start this script again." >&2
      exit 2
    fi
  fi
  sleep 60
done

echo "No Codex review of PR #$pr at head $head after $max minutes (expected commit: ${expected:-none})." >&2
exit 1
