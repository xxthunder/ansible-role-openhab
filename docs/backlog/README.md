# Backlog

## Status Legend

- **Open** - Ready to be picked up
- **In Progress** - Currently being worked on
- **Done** - Completed

## Table of Contents

### Open
- [ARO-005 — Settle the tagging and release policy](aro-005.md)

### In Progress
- [ARO-002 — Seed `conf/` and `userdata/` from two repositories](aro-002.md)
- [ARO-001 — Scaffold the repo for standalone agentic development](aro-001.md)

### Done
- [ARO-004 — Add CI and meet the publishing bar](aro-004.md)
- [ARO-003 — Repair or retire `molecule/default`](aro-003.md)

## Notes

- **ID prefix: `ARO-`** (ansible-role-openhab). One file per item at
  `docs/backlog/aro-###.md`, lowercase; substories take a letter suffix
  (`aro-002a.md`). Enforced on every commit by `.githooks/commit-msg`.
- **This backlog owns role internals.** The consuming project tracks only what
  *it* must do — its `group_vars`, its playbook, its submodule pin. Anything
  inside this repo is tracked here.
- **Cross-repo references are IDs, never links.** An item in a consumer's
  backlog is cited as e.g. `HSH-067`, with no URL. This is one case of the
  general rule — see "This repo is public" in `AGENTS.md`. Every item here
  should read completely without following such a reference.
- **Merging is not releasing.** This role is consumed as a submodule pinned to a
  tag, so a Done item changes nothing for the consumer until a tag is cut and
  the pin advances. Items that must reach a real host say so in their criteria.
