#!/usr/bin/env bash
# Wait for the Codex review of the current head of a pull request and print it.
# Only for repositories of the Merlin-Digital-Solutions organization: the
# review comes from the codex-review.yml workflow, which posts a comment that
# starts with "<!-- codex-review -->".
#
# Usage: bash wait-review.sh [PR-NUMBER] [MAX-MINUTES] [SHA]
#   PR-NUMBER    defaults to the pull request of the current branch
#   MAX-MINUTES  defaults to 30
#   SHA          the commit you pushed, full or short. Defaults to the local
#                HEAD when the current branch is the head branch of the PR. The
#                script waits until the PR head is this commit or a later one
#                (for example a commit of the migration bot), so it never
#                returns the review of the push before.
# Exit 0: the review of the current head is on stdout.
# Exit 1: no review came in time.
# Exit 2: the PR is a draft. codex-review.yml skips drafts, so no review comes.
set -euo pipefail

pr=${1:-$(gh pr view --json number --jq .number)}
max=${2:-30}
expected=${3:-}
marker='<!-- codex-review -->'
ref=$(gh pr view "$pr" --json headRefName --jq .headRefName)

if [[ -z $expected ]]; then
  branch=$(git branch --show-current 2>/dev/null || true)
  [[ -n $branch && $branch == "$ref" ]] && expected=$(git rev-parse HEAD)
elif full=$(git rev-parse --verify --quiet "$expected^{commit}" 2>/dev/null); then
  expected=$full
fi

# True when commit $2 is commit $1 or a commit after it. GitHub's compare
# answers "identical" for the same commit, also when $1 is a short sha.
at_or_after() {
  [[ $1 == "$2" ]] && return 0
  local status
  status=$(gh api "repos/{owner}/{repo}/compare/$1...$2" --jq .status 2>/dev/null || true)
  [[ $status == identical || $status == ahead ]]
}

# The id of the newest review comment for the PR head $1, or nothing. The
# review belongs to the newest codex-review.yml run that really ran (not
# skipped, as for the migration bot's pushes) for a commit between the
# expected commit and the head; the comment must be younger than that run.
# Without such a run there is no review yet: a comment of an older run must
# never count as the review of this head.
review_of() {
  local runs sha created since=''
  runs=$(gh api "repos/{owner}/{repo}/actions/workflows/codex-review.yml/runs?branch=$ref&per_page=50" \
    --jq '.workflow_runs[] | select(.conclusion != "skipped") | "\(.head_sha) \(.created_at)"' 2>/dev/null) || return 0
  while read -r sha created; do
    [[ -n $sha ]] || continue
    if at_or_after "$sha" "$1" && { [[ -z $expected ]] || at_or_after "$expected" "$sha"; }; then
      since=$created
      break
    fi
  done <<< "$runs"
  [[ -n $since ]] || return 0
  gh api --paginate "repos/{owner}/{repo}/issues/$pr/comments?per_page=100" \
    --jq ".[] | select(.created_at > \"$since\" and (.body | startswith(\"$marker\"))) | .id" 2>/dev/null | tail -n 1
}

for ((minute = 0; minute < max; minute++)); do
  read -r head draft < <(gh pr view "$pr" --json headRefOid,isDraft --jq '"\(.headRefOid) \(.isDraft)"')
  if [[ -z $expected ]] || at_or_after "$expected" "$head"; then
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
