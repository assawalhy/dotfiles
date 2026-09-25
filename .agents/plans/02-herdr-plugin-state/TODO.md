# TODO

- [x] link-ignore.txt: add herdr runtime + plugin install/state block
- [x] add setup/steps/65-herdr-stay-awake.sh and make it executable
- [x] tests/link-files.bats: audit test for herdr plugin/runtime suppression
- [x] final verify: bash -n, bats main suite, --audit 34 -> 2, setup-os --list shows step
  - bats main: 98 ok, 0 not ok (was 97 ok + 1 pre-existing failure)
- [x] fix stale assertion in `au_skip` (`keep.conf [unlinked]` -> `output_has_finding`) + AGENTS count 97 -> 98

