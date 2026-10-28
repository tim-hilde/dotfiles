#!/usr/bin/env zsh
# Run: zsh tests/wt-prune.test.zsh

source ${0:A:h}/../aliases

tmp=$(mktemp -d)
trap 'rm -rf $tmp' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

fails=0
assert_contains() {
  [[ $1 == *"$2"* ]] || { print -r -- "FAIL: expected to contain: $2"; (( fails++ )) }
}
assert_not_contains() {
  [[ $1 != *"$2"* ]] || { print -r -- "FAIL: expected not to contain: $2"; (( fails++ )) }
}
assert_true() {
  eval "$1" || { print -r -- "FAIL: $1"; (( fails++ )) }
}

mkdir -p $tmp/bin $tmp/empty-root
cat > $tmp/bin/gh <<'EOF'
#!/usr/bin/env zsh
head=""
while (( $# )); do
  [[ $1 == --head ]] && { head=$2; break }
  shift
done
while read -r branch number oid; do
  [[ $branch == $head ]] || continue
  [[ $number == FAIL ]] && { print -u2 "fake gh: request failed"; exit 1 }
  print "$number $oid"
done < $FAKE_GH_MAP
EOF
chmod +x $tmp/bin/gh
export PATH=$tmp/bin:$PATH
export FAKE_GH_MAP=$tmp/gh-map
: > $FAKE_GH_MAP

origin=$tmp/origin-a
wts=$tmp/wts
git init -q -b main $origin
git -C $origin remote add origin git@github.com:test/repo-a.git
print "/// <reference types=\"next\" />" > $origin/next-env.d.ts
git -C $origin add next-env.d.ts
git -C $origin commit -qm base

mkwt() {
  local rel=$1 branch=$2 commits=$3 i
  if [[ $branch == --detach ]]; then
    git -C $origin worktree add -q --detach $wts/$rel main
  else
    git -C $origin worktree add -q -b $branch $wts/$rel main
  fi
  for (( i = 1; i <= commits; i++ )); do
    print "$rel $i" > $wts/$rel/file-$i
    git -C $wts/$rel add file-$i
    git -C $wts/$rel commit -qm "commit $i"
  done
}

merged() {
  print "$2 $3 $(git -C $wts/$1 rev-parse ${4:-HEAD})" >> $FAKE_GH_MAP
}

mkwt feat/merged-clean feat/merged-clean 1;        merged feat/merged-clean feat/merged-clean 11
mkwt fix/merged-infisical fix/merged-infisical 1;  merged fix/merged-infisical fix/merged-infisical 12
mkwt fix/merged-nextenv fix/merged-nextenv 1;      merged fix/merged-nextenv fix/merged-nextenv 13
mkwt fix/merged-dirty fix/merged-dirty 1;          merged fix/merged-dirty fix/merged-dirty 14
mkwt feat/head-differs feat/head-differs 2;        merged feat/head-differs feat/head-differs 15 HEAD~1
mkwt feat/no-pr feat/no-pr 1
mkwt detached --detach 0
mkwt feat/combo/repo-a feat/combo 0;               merged feat/combo/repo-a feat/combo 16
mkwt chore/gh-fails chore/gh-fails 0;              print "chore/gh-fails FAIL" >> $FAKE_GH_MAP
mkwt docs/only-merged docs/only-merged 0;          merged docs/only-merged docs/only-merged 17

touch $wts/fix/merged-infisical/.infisical.yaml
print "// regenerated" >> $wts/fix/merged-nextenv/next-env.d.ts
touch $wts/fix/merged-dirty/notes.md
touch $wts/docs/.DS_Store

safe=(feat/merged-clean fix/merged-infisical fix/merged-nextenv feat/combo/repo-a docs/only-merged)
kept=(fix/merged-dirty feat/head-differs feat/no-pr detached chore/gh-fails)

# test_lists_safe_and_cancels_on_n
out=$(print n | wt-prune $tmp/wts 2>$tmp/err)
for p in $safe; assert_contains "$out" "$p"
assert_contains "$out" "  feat/merged-clean  (origin-a, PR #11)"
for p in $kept; assert_not_contains "$out" "$p"
assert_contains "$(<$tmp/err)" "gh-Fehler bei chore/gh-fails, übersprungen"
assert_contains "$out" "Abgebrochen, nichts gelöscht."
for p in $safe $kept; assert_true "[[ -d $tmp/wts/$p ]]"

# test_empty_answer_deletes_nothing
out=$(print "" | wt-prune $tmp/wts 2>/dev/null)
assert_contains "$out" "Abgebrochen, nichts gelöscht."
for p in $safe; assert_true "[[ -d $tmp/wts/$p ]]"

# test_no_candidates_skips_prompt
out=$(print y | wt-prune $tmp/empty-root)
assert_contains "$out" "Keine sicher löschbaren Worktrees."
assert_not_contains "$out" "Abgebrochen"

# test_y_deletes_safe_worktrees_and_branches
out=$(print y | wt-prune $tmp/wts 2>$tmp/err)
for p in $safe; assert_contains "$out" "gelöscht: $p"
for p in $safe; assert_true "[[ ! -e $tmp/wts/$p ]]"
for b in feat/merged-clean fix/merged-infisical fix/merged-nextenv feat/combo docs/only-merged; do
  assert_true "! git -C $tmp/origin-a show-ref --verify --quiet refs/heads/$b"
done
for p in $kept; assert_true "[[ -d $tmp/wts/$p ]]"
assert_true "git -C $tmp/origin-a show-ref --verify --quiet refs/heads/feat/head-differs"
assert_true "[[ ! -e $tmp/wts/docs ]]"
assert_true "[[ ! -e $tmp/wts/feat/combo ]]"
assert_true "[[ -d $tmp/wts/feat ]]"
assert_true "(( \$(git -C $tmp/origin-a worktree list | wc -l) == 6 ))"

if (( fails )); then
  print "$fails assertion(s) failed"
  exit 1
fi
print ok
