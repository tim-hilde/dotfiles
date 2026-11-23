#!/usr/bin/env zsh
# Run: zsh tests/wt-prune.test.zsh

source ${0:A:h}/../aliases

tmp=${$(mktemp -d):A}
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

group_of() {
  setopt localoptions extendedglob
  local line group=""
  for line in ${(f)1}; do
    if [[ $line == (#b)([^\ ]*)' ('<->', '* ]]; then
      group=$match[1]
    elif [[ $line == ' '#<->'  '"$2"'  ('* ]]; then
      print -r -- $group
      return
    fi
  done
}
num_of() {
  setopt localoptions extendedglob
  local line
  for line in ${(f)1}; do
    [[ $line == (#b)' '#(<->)'  '"$2"'  ('* ]] && { print $match[1]; return }
  done
}
assert_group() {
  local got=$(group_of "$out" $1)
  [[ $got == "$2" ]] || { print -r -- "FAIL: $1 is in group [$got], expected [$2]"; (( fails++ )) }
}

mkdir -p $tmp/bin $tmp/empty-root
cat > $tmp/bin/gh <<'EOF'
#!/usr/bin/env zsh
head=""
while (( $# )); do
  [[ $1 == --head ]] && { head=$2; break }
  shift
done
while read -r branch number state base oid; do
  [[ $branch == $head ]] || continue
  [[ $number == FAIL ]] && { print -u2 "fake gh: request failed"; exit 1 }
  print "$number $state $base $oid"
done < $FAKE_GH_MAP
EOF
chmod +x $tmp/bin/gh
export PATH=$tmp/bin:$PATH
export FAKE_GH_MAP=$tmp/gh-map
: > $FAKE_GH_MAP

mkrepo() {
  local name=$1
  git init -q --bare -b main $tmp/remote-$name.git
  git init -q -b main $tmp/origin-$name
  git -C $tmp/origin-$name remote add origin git@github.com:test/repo-$name.git
  git -C $tmp/origin-$name config url.$tmp/remote-$name.git.insteadOf git@github.com:test/repo-$name.git
  print "/// <reference types=\"next\" />" > $tmp/origin-$name/next-env.d.ts
  print "{}" > $tmp/origin-$name/package-lock.json
  git -C $tmp/origin-$name add next-env.d.ts package-lock.json
  git -C $tmp/origin-$name commit -qm base
  git -C $tmp/origin-$name push -q origin main main:staging
  git -C $tmp/origin-$name fetch -q origin
}

mkwt() {
  local rel=$1 branch=$2 commits=$3 i
  if [[ $branch == --detach ]]; then
    git -C $origin worktree add -q --detach $wts/$rel main
  else
    git -C $origin worktree add -q -b $branch $wts/$rel main
  fi
  for (( i = 1; i <= commits; i++ )); do
    commit $rel $i
  done
}
commit() {
  local file=${1//\//_}-$2.txt
  print "$1 $2" > $wts/$1/$file
  git -C $wts/$1 add $file
  git -C $wts/$1 commit -qm "$1 commit $2"
}
pr() {
  print "$2 $3 $4 $5 $(git -C $wts/$1 rev-parse ${6:-HEAD})" >> $FAKE_GH_MAP
}

mkrepo a
origin=$tmp/origin-a
wts=$tmp/wts

mkwt fix/merged-same fix/merged-same 1
dd if=/dev/zero of=$wts/fix/merged-same/big.bin bs=1024 count=2048 2>/dev/null
git -C $wts/fix/merged-same add big.bin
git -C $wts/fix/merged-same commit -qm big
pr fix/merged-same fix/merged-same 11 MERGED staging
mkwt fix/merged-behind fix/merged-behind 2;            pr fix/merged-behind fix/merged-behind 12 MERGED staging
git -C $wts/fix/merged-behind reset -q --hard HEAD~1
mkwt fix/merged-landed fix/merged-landed 1;            pr fix/merged-landed fix/merged-landed 13 MERGED staging
commit fix/merged-landed 2
mkwt fix/closed-same fix/closed-same 1;                pr fix/closed-same fix/closed-same 14 CLOSED staging
git -C $wts/fix/closed-same push -q origin fix/closed-same
mkwt fix/merged-leftovers fix/merged-leftovers 1;      pr fix/merged-leftovers fix/merged-leftovers 16 MERGED staging
mkwt feat/combo/repo-a feat/combo 0;                   pr feat/combo/repo-a feat/combo 19 MERGED staging
mkwt docs/only-merged docs/only-merged 0;              pr docs/only-merged docs/only-merged 20 MERGED staging
mkwt fix/merged-gone-base fix/merged-gone-base 1;      pr fix/merged-gone-base fix/merged-gone-base 21 MERGED release/x
mkwt feat/open-pr feat/open-pr 1;                      pr feat/open-pr feat/open-pr 18 OPEN staging
mkwt renovate/stack renovate/stack 2;                  pr renovate/stack renovate/stack 23 OPEN staging
pr renovate/stack renovate/stack 22 MERGED staging HEAD~1
mkwt fix/merged-dirty fix/merged-dirty 1;              pr fix/merged-dirty fix/merged-dirty 17 MERGED staging
mkwt detached-dirty --detach 0
mkwt fix/closed-more fix/closed-more 2;                pr fix/closed-more fix/closed-more 15 CLOSED staging HEAD~1
mkwt fix/merged-missing-head fix/merged-missing-head 1
print "fix/merged-missing-head 24 MERGED staging aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" >> $FAKE_GH_MAP
mkwt feat/no-pr feat/no-pr 1
mkwt feat/no-pr-pushed feat/no-pr-pushed 1
git -C $wts/feat/no-pr-pushed push -q origin feat/no-pr-pushed
mkwt chore/gh-fails chore/gh-fails 1;                  print "chore/gh-fails FAIL" >> $FAKE_GH_MAP
mkwt chore/empty chore/empty 0
mkwt detached --detach 0
mkwt fix/landed-no-pr fix/landed-no-pr 1
mkwt feat/squashed feat/squashed 2
mkwt fix/broken-index fix/broken-index 1
print garbage > $(git -C $wts/fix/broken-index rev-parse --path-format=absolute --git-path index)

touch $wts/fix/merged-leftovers/.infisical.yaml $wts/fix/merged-leftovers/AGENTS.md
print "// regenerated" >> $wts/fix/merged-leftovers/next-env.d.ts
print "{ }" >> $wts/fix/merged-leftovers/package-lock.json
ln -s /nonexistent/node_modules $wts/fix/merged-leftovers/node_modules
touch $wts/fix/merged-dirty/notes.md $wts/detached-dirty/x.txt $wts/docs/.DS_Store
mkdir -p $wts/_brief $wts/leer $wts/fix/notes
touch $wts/_brief/a.md $wts/fix/notes/x.md

# Land commits on the remote staging without updating origin/staging in the main repo.
stale=$(git -C $origin rev-parse origin/staging)
git -C $origin worktree add -q --detach $tmp/landing origin/staging
git -C $tmp/landing cherry-pick $(git -C $wts/fix/merged-landed rev-parse HEAD) >/dev/null
git -C $tmp/landing cherry-pick $(git -C $wts/fix/landed-no-pr rev-parse HEAD) >/dev/null
git -C $tmp/landing checkout -q $(git -C $wts/feat/squashed rev-parse HEAD) -- feat_squashed-1.txt feat_squashed-2.txt
git -C $tmp/landing commit -qm squash
git -C $tmp/landing push -q $tmp/remote-a.git HEAD:refs/heads/staging
git -C $origin worktree remove --force $tmp/landing
git -C $origin update-ref refs/remotes/origin/staging $stale

mkrepo b
git -C $tmp/origin-b worktree add -q -b feat/offline $tmp/wts-offline/feat/offline main
mv $tmp/remote-b.git $tmp/remote-b-gone.git

typeset -A expected=(
  fix/merged-same "Sicher löschbar"
  fix/merged-behind "Sicher löschbar"
  fix/merged-landed "Sicher löschbar"
  fix/closed-same "Sicher löschbar"
  fix/merged-leftovers "Sicher löschbar"
  feat/combo/repo-a "Sicher löschbar"
  docs/only-merged "Sicher löschbar"
  fix/merged-gone-base "Sicher löschbar"
  feat/open-pr "PR offen"
  renovate/stack "PR offen"
  fix/merged-dirty "Nicht committete Änderungen"
  detached-dirty "Nicht committete Änderungen"
  fix/closed-more "Eigene Commits"
  fix/merged-missing-head "Eigene Commits"
  feat/no-pr "Eigene Commits"
  feat/no-pr-pushed "Eigene Commits"
  chore/gh-fails "Eigene Commits"
  chore/empty "Ohne eigene Arbeit"
  detached "Ohne eigene Arbeit"
  fix/landed-no-pr "Ohne eigene Arbeit"
  feat/squashed "Ohne eigene Arbeit"
)

# test_size_formats_kilo_mega_giga
assert_true '[[ $(_wt_prune_size 20) == 20K ]]'
assert_true '[[ $(_wt_prune_size 1023) == 1023K ]]'
assert_true '[[ $(_wt_prune_size 1024) == 1.0M ]]'
assert_true '[[ $(_wt_prune_size 1536) == 1.5M ]]'
assert_true '[[ $(_wt_prune_size 1048576) == 1.0G ]]'
assert_true '[[ $(_wt_prune_size 3460300) == 3.3G ]]'
assert_true '[[ $(LC_ALL=de_DE.UTF-8 _wt_prune_size 1536) == 1.5M ]]'

# test_age_german
for s want in 30 "gerade eben" 60 "vor 1 Minute" 120 "vor 2 Minuten" 3600 "vor 1 Stunde" 7200 "vor 2 Stunden" \
    86400 "vor 1 Tag" 172800 "vor 2 Tagen" 604800 "vor 7 Tagen" 1209600 "vor 2 Wochen" 2592000 "vor 4 Wochen" \
    6048000 "vor 2 Monaten"; do
  got=$(_wt_prune_age $s 2>&1)
  [[ $got == "$want" ]] || { print -r -- "FAIL: _wt_prune_age $s gave [$got], expected [$want]"; (( fails++ )) }
done

# test_changes_filters_leftovers
assert_true '[[ -z "$(_wt_prune_changes $wts/fix/merged-leftovers 2>&1)" ]]'
assert_true '[[ "$(_wt_prune_changes $wts/fix/merged-dirty 2>&1)" == "?? notes.md" ]]'
assert_true '! _wt_prune_changes $wts/fix/broken-index >/dev/null 2>&1'

# test_overview_groups_and_cancel
out=$(print "" | wt-prune $wts 2>$tmp/err)
for rel grp in ${(kv)expected}; assert_group $rel $grp
assert_contains "$out" "Sicher löschbar (8, "
assert_contains "$out" "Ohne eigene Arbeit (4, "
assert_contains "$out" "PR offen (2, "
assert_contains "$out" "Eigene Commits (5, "
assert_contains "$out" "Nicht committete Änderungen (2, "
assert_contains "$out" "  fix/merged-same  (origin-a, PR #11 gemergt, 2.0M, "
assert_contains "$out" "  fix/closed-same  (origin-a, PR #14 geschlossen, "
assert_contains "$out" "  fix/closed-more  (origin-a, PR #15 geschlossen, 2 Commits, 2 nur lokal, "
assert_contains "$out" "  feat/no-pr-pushed  (origin-a, 1 Commit, "
assert_not_contains "$out" "  feat/no-pr-pushed  (origin-a, 1 Commit, 1 nur lokal"
assert_contains "$out" "  feat/open-pr  (origin-a, PR #18 offen, 1 Commit, 1 nur lokal, "
assert_contains "$out" "  renovate/stack  (origin-a, PR #23 offen, "
assert_contains "$out" "  fix/merged-dirty  (origin-a, PR #17 gemergt, 1 Commit, 1 nur lokal, 1 Änderung, "
assert_contains "$out" "  detached  (origin-a, detached, "
assert_contains "$out" "  chore/gh-fails  (origin-a, 1 Commit, 1 nur lokal, PR-Status unbekannt, "
assert_contains "$out" "Gesamt: 21 Worktrees, "
assert_contains "$out" "_brief (1 Datei)"
assert_contains "$out" "leer (leer)"
assert_contains "$out" "fix/notes (1 Datei)"
assert_not_contains "$out" "fix/broken-index  ("
assert_contains "$(<$tmp/err)" "git-Fehler bei fix/broken-index, übersprungen"
assert_contains "$out" "Welche löschen? Nummern oder Bereiche wie 3-9, s für alle sicheren, Enter für keine: "
assert_contains "$out" "Abgebrochen, nichts gelöscht."
for rel in ${(k)expected} fix/broken-index; assert_true "[[ -d $wts/$rel ]]"

# test_eof_deletes_nothing
out=$(wt-prune $wts </dev/null 2>/dev/null)
assert_contains "$out" "Abgebrochen, nichts gelöscht."
for rel in ${(k)expected}; assert_true "[[ -d $wts/$rel ]]"

# test_fetch_failure_warns
out=$(print "" | wt-prune $tmp/wts-offline 2>$tmp/err)
assert_contains "$(<$tmp/err)" "fetch fehlgeschlagen bei origin-b, Stand kann veraltet sein"
assert_contains "$out" "  feat/offline  (origin-b, "

# test_no_base_branch_counts_as_own_commits
git init -q --bare -b master $tmp/remote-c.git
git init -q -b master $tmp/origin-c
git -C $tmp/origin-c remote add origin $tmp/remote-c.git
print c > $tmp/origin-c/c.txt
git -C $tmp/origin-c add c.txt
git -C $tmp/origin-c commit -qm base
git -C $tmp/origin-c push -q origin master
git -C $tmp/origin-c worktree add -q -b feat/no-base $tmp/wts-nobase/feat/no-base master
print x > $tmp/wts-nobase/feat/no-base/x.txt
git -C $tmp/wts-nobase/feat/no-base add x.txt
git -C $tmp/wts-nobase/feat/no-base commit -qm work
git -C $tmp/wts-nobase/feat/no-base push -q origin feat/no-base
out=$(print "" | wt-prune $tmp/wts-nobase 2>/dev/null)
assert_contains "$out" "Eigene Commits (1, "
assert_contains "$out" "  feat/no-base  (origin-c, Basis unbekannt, "

# test_no_worktrees
out=$(wt-prune $tmp/empty-root </dev/null 2>&1)
assert_contains "$out" "Keine Worktrees in $tmp/empty-root."

# test_select
assert_true '[[ "$(_wt_prune_select "1 3-4,s 3" 9 7 8 2>&1)" == "1 3 4 7 8" ]]'
assert_true '[[ -z "$(_wt_prune_select "" 9 2>&1)" ]]'
assert_true '[[ -z "$(_wt_prune_select s 9 2>&1)" ]]'
for bad in x 0 10 4-2 3- -; assert_true "! _wt_prune_select '$bad' 9 >/dev/null 2>&1"

# test_invalid_selection_deletes_nothing
out=$(print "abc" | wt-prune $wts 2>&1); rc=$?
assert_true "(( rc == 1 ))"
assert_contains "$out" 'Ungültige Eingabe "abc". Erlaubt sind Nummern, Bereiche wie 3-9 und s. Nichts gelöscht.'
for rel in ${(k)expected}; assert_true "[[ -d $wts/$rel ]]"

# test_second_confirmation_n_keeps_work
n=$(num_of "$out" feat/no-pr)
out=$(print "$n\nn" | wt-prune $wts 2>&1)
assert_contains "$out" "Diese Worktrees enthalten Arbeit, die nur hier liegt:"
assert_contains "$out" "  $n  feat/no-pr: 1 Commit nur lokal"
assert_contains "$out" "      $(git -C $wts/feat/no-pr log -1 --format='%h %s')"
assert_contains "$out" "Trotzdem löschen? [y/N] "
assert_contains "$out" "Abgebrochen, nichts gelöscht."
assert_true "[[ -d $wts/feat/no-pr ]]"

# test_second_confirmation_y_deletes_and_prints_restore
sha=$(git -C $wts/feat/no-pr rev-parse --short=12 HEAD)
out=$(print "$n\ny" | wt-prune $wts 2>&1)
assert_contains "$out" "gelöscht: feat/no-pr"
assert_contains "$out" "  wiederherstellen: git -C $origin branch feat/no-pr $sha"
assert_true "[[ ! -e $wts/feat/no-pr ]]"
assert_true "! git -C $origin show-ref --verify --quiet refs/heads/feat/no-pr"
unset 'expected[feat/no-pr]'

# test_no_local_work_needs_no_second_confirmation
out=$(print "" | wt-prune $wts 2>&1)
out=$(print "$(num_of "$out" chore/empty) $(num_of "$out" detached)" | wt-prune $wts 2>&1)
assert_not_contains "$out" "Trotzdem löschen"
assert_contains "$out" "gelöscht: chore/empty"
assert_contains "$out" "gelöscht: detached"
assert_not_contains "$out" "wiederherstellen"
assert_true "[[ ! -e $wts/chore/empty && ! -e $wts/detached ]]"
assert_true "! git -C $origin show-ref --verify --quiet refs/heads/chore/empty"
unset 'expected[chore/empty]' 'expected[detached]'

# test_changes_alone_need_second_confirmation
out=$(print "" | wt-prune $wts 2>&1)
out=$(print "$(num_of "$out" detached-dirty)\nn" | wt-prune $wts 2>&1)
assert_contains "$out" "detached-dirty: 1 Änderung"
assert_contains "$out" "      ?? x.txt"
assert_contains "$out" "Abgebrochen, nichts gelöscht."
assert_true "[[ -d $wts/detached-dirty ]]"

# test_s_deletes_safe_only
sha_same=$(git -C $wts/fix/merged-same rev-parse --short=12 HEAD)
out=$(print s | wt-prune $wts 2>&1)
assert_contains "$out" "  wiederherstellen: git -C $origin branch fix/merged-same $sha_same"
assert_not_contains "$out" "branch fix/closed-same "
assert_not_contains "$out" "Trotzdem löschen"
for rel grp in ${(kv)expected}; do
  if [[ $grp == "Sicher löschbar" ]]; then
    assert_contains "$out" "gelöscht: $rel"
    assert_true "[[ ! -e $wts/$rel ]]"
  else
    assert_true "[[ -d $wts/$rel ]]"
  fi
done
for b in fix/merged-same fix/merged-behind fix/merged-landed fix/closed-same fix/merged-leftovers feat/combo \
    docs/only-merged fix/merged-gone-base; do
  assert_true "! git -C $origin show-ref --verify --quiet refs/heads/$b"
done
assert_true "git -C $origin show-ref --verify --quiet refs/heads/fix/closed-more"
assert_true "[[ ! -e $wts/docs && ! -e $wts/feat/combo && -d $wts/feat ]]"

# test_yes_deletes_safe_without_prompt
wts=$tmp/wts-yes
mkwt feat/yes-merged feat/yes-merged 1;   pr feat/yes-merged feat/yes-merged 31 MERGED staging
mkwt feat/yes-kept feat/yes-kept 1
out=$(wt-prune --yes $wts </dev/null 2>&1)
assert_contains "$out" "Lösche alle 1 sicheren Worktrees (insgesamt "
assert_contains "$out" "gelöscht: feat/yes-merged"
assert_not_contains "$out" "Welche löschen?"
assert_not_contains "$out" "Trotzdem löschen"
assert_true "[[ ! -e $wts/feat/yes-merged && -d $wts/feat/yes-kept ]]"

# test_yes_without_safe
out=$(wt-prune --yes $wts </dev/null 2>&1)
assert_contains "$out" "Keine sicher löschbaren Worktrees."
assert_true "[[ -d $wts/feat/yes-kept ]]"

# test_empty_root_argument_uses_default
wts=$tmp/home/code/merlin/worktrees
mkwt feat/yes-default feat/yes-default 1; pr feat/yes-default feat/yes-default 32 MERGED staging
out=$(HOME=$tmp/home wt-prune "" --yes </dev/null 2>&1)
assert_contains "$out" "gelöscht: feat/yes-default"
assert_true "[[ ! -e $wts/feat/yes-default ]]"

# test_unknown_option_is_rejected
out=$(wt-prune -y $wts </dev/null 2>&1)
assert_true "(( $? == 2 ))"
assert_contains "$out" "Aufruf: wt-prune [--yes] [Ordner]"

# test_second_root_is_rejected
out=$(wt-prune --yes $wts $tmp/empty-root </dev/null 2>&1)
assert_true "(( $? == 2 ))"
assert_contains "$out" "Aufruf: wt-prune [--yes] [Ordner]"

if (( fails )); then
  print "$fails assertion(s) failed"
  exit 1
fi
print ok
