# AGENTS.md — AI Agent Guidelines for `ansible-role-openhab`

## What this repo is

An Ansible role that runs openHAB as a Docker container and seeds its
configuration and runtime state from two git repositories. It is a standalone,
reusable role: nothing in it may assume the maintainer's home lab.

**It is consumed as a git submodule, pinned to a tag.** The consuming project
mounts it at `roles/openhab`. The practical consequence is easy to forget and
worth stating plainly: **a commit here changes nothing anywhere until the consumer's
pin moves.** Merging to `main` is not deployment. A change is live only once a
tag is cut and the parent advances its submodule to it.

**Lineage.** This began as a fork of
[`fex01/ansible-openhab`](https://github.com/fex01/ansible-openhab), itself
inspired by [rkoshak](https://github.com/rkoshak)'s *Ansible Revisited*. The
divergence is permanent — the `xxthunder` copy is not maintained as a fork and
does not track upstream. Attribution stays; lineage does not.

## This repo is public

Nothing in it may name the maintainer's lab: host names, IP addresses, internal
domains or URLs, the lab's own name, the consuming project's name, or family
members. This covers **prose, comments, examples and commit messages**, not just
links and config. Write the generic form instead — "any Docker-capable host",
"the consuming project" — which reads better anyway.

The maintainer's own name is not a lab identifier. It is in every commit's
author line, and it belongs wherever authorship is stated, such as `LICENSE`.

Consumer backlog items are cited by bare ID (e.g. `HSH-067`), never as a link:
an ID is opaque, a URL is not, and a link would be dead for most readers.

This is "nothing in it may assume the maintainer's home lab" from above, stated
where it can be checked before a push rather than noticed after one. Grep the
branch — the working tree *and* every commit on it — before pushing, and read
the grep's own exit status: a piped grep reports the pipe's status, not its own.

## Backlog

Work is tracked in `docs/backlog/` with the **`ARO-`** prefix, one file per item
(`docs/backlog/aro-###.md`), indexed in `docs/backlog/README.md`. Every commit
references an item — the `commit-msg` hook enforces it.

Enable the hook after cloning (it is not automatic):

```sh
git config core.hooksPath .githooks
```

Format: `<type>(<scope>): <description> (ARO-###)`. Allowed types: `feat`, `fix`,
`docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

## Git workflow

Anything that changes what runs — tasks, defaults, templates, molecule — is
developed on a short-lived feature branch and merged to `main` fast-forward only
(`git merge --ff-only`). Pure backlog and documentation edits may go straight to
`main`.

## Testing

**`scripts/test.sh` is the single entry point** — the same run on a laptop, on
any Docker host and in CI. It needs only `uv` and a Docker daemon the user can
reach; `pyproject.toml` and `uv.lock` pin the whole toolchain (ansible-core,
ansible-lint, yamllint, Molecule), and `requirements.yml` pins the collections,
which the script installs into the checkout's `.ansible/collections/`.

```sh
scripts/test.sh        # yamllint, ansible-lint, then every Molecule scenario
scripts/test.sh lint   # the static checks only
```

**`molecule/git-seeding`** covers the two-repo seeding contract against bare
repositories created inside the container, so it needs no network, no git
server and no credentials. It converges `tasks/git.yml` alone — never the whole
role — so it needs no docker-in-docker for the openHAB container. Its image is
pinned by digest.

Every run logs `CRITICAL 'molecule/default/molecule.yml' glob failed`, followed
by `default scenario not found, disabling shared state.` That is Molecule
probing for a `default` scenario to share state with: its config loader logs
the miss as critical before the caller catches it and carries on. It is
expected here and changes nothing.

**`molecule/operator-write`** covers the operator's write access against the
image entrypoint's `chown -R` ([ARO-007](docs/backlog/aro-007.md)). It
converges `tasks/permissions.yml` alone, with the same pinned image.

There is no full-role scenario: the openHAB container start is verified on a
real host at the release-candidate step ([ARO-003](docs/backlog/aro-003.md)).
A new scenario is focused on one concern and asserts something that fails when
that concern breaks.

`ansible-lint` is deliberately **not** in `.claude/settings.json`'s deny list.
The consumer repo denies the whole `ansible*` glob to protect a vault; this repo
has no vault, and linting a role is exactly the kind of thing an agent should be
able to do here. Playbook execution against real infrastructure stays denied —
and an operator's own agent policy may be stricter than this file.

## Releasing — RC first, then promote

A change here is not "released" when it merges. Cut a **release candidate**
first, let the consumer verify it against a real host, and only then promote:

1. Tag `vX.Y.Z-rcN` at the fix commit, push it, and have the consumer bump its
   pin to the RC.
2. Verify against the real target — molecule plus whatever reboot-survival or
   idempotence check the change warrants.
3. Only on success, tag the final `vX.Y.Z` and re-point the consumer's pin.

The RC keeps "pinned for testing" distinct from "released", so an unverified
build is never blessed as a version.

## Conventions

- **Role variables** are prefixed `openhab_` and documented in
  `defaults/main.yml` with a comment saying what they do and what empty means.
- **Optional features default to off.** An empty string, not `null` — guards use
  `| length > 0`, and `null | length` raises rather than returning 0.
- **Never reference a credential on the managed host.** The role authenticates
  to nothing in steady state; an earlier version passed `key_file` pointing at a
  private key on the box, and that is precisely what was removed. A seed
  authenticates with the agent the operator forwards for that one run.
- **KISS / YAGNI.** No variable, wrapper or knob without a current backlog item
  needing it. One-time migration steps belong in the consumer's runbook, not in
  role logic that then runs forever.
- **Single responsibility per task file.** `tasks/git.yml` owns repository
  wiring; `tasks/permissions.yml` the tree's ownership, modes and ACLs;
  `tasks/main.yml` orchestrates.

## Definition of Done

A change is done when the docs describing it are true again, in the same commit:
the backlog item's criteria ticked, `defaults/main.yml` commented for any new
variable, and `README.md` updated if the role's behaviour or interface changed.
