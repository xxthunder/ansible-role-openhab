# Ansible Role: openhab

[![CI](https://github.com/xxthunder/ansible-role-openhab/actions/workflows/test.yml/badge.svg)](https://github.com/xxthunder/ansible-role-openhab/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Ansible](https://img.shields.io/badge/Ansible-2.17%2B-blue.svg)](https://docs.ansible.com/)
[![ansible-lint](https://img.shields.io/badge/ansible--lint-passing-brightgreen.svg)](https://ansible.readthedocs.io/projects/lint/)

Run [openHAB](https://www.openhab.org) as a Docker container on Debian, and seed
its configuration and runtime state from two optional git repositories — without
any code path that could reset a populated tree.

The role

- creates the openHAB service account and adds a host user to its group,
- seeds `conf/` and `userdata/` from separate repositories, once (see
  [Two repositories](#two-repositories-config-and-state)),
- creates the folders the openHAB image needs and sets their ownership,
- keeps what the operator creates in `conf/` and `userdata/` writable across
  container restarts (see [Operator access](#operator-access)),
- pulls the requested `openhab/openhab` image and recreates the container if it
  changed, with host networking.

> **Lineage.** This repository began as a fork of
> [`fex01/ansible-openhab`](https://github.com/fex01/ansible-openhab), inspired by
> [rkoshak](https://github.com/rkoshak)'s post
> [Ansible Revisited](https://community.openhab.org/t/ansible-revisited/105754) in
> the openHAB community. It has permanently diverged: it is maintained under
> `xxthunder` on its own release line and does not track upstream. Attribution
> stands — this note is about lineage, not credit.
>
> Development conventions and the release process are in [AGENTS.md](AGENTS.md);
> work is tracked in [docs/backlog/](docs/backlog/).

## Requirements

- Debian 12 (bookworm) or 13 (trixie) with Docker and git installed.
- The `community.docker` and `ansible.posix` collections on the controller
  (`requirements.yml`).
- A file system under `openhab_home` with POSIX ACLs, as ext4, XFS and Btrfs
  have by default. The role installs the `acl` package.
- A role named **`create-service-account`** on the roles path, which this role
  includes to create the service account. It is not part of this repository;
  it receives `service_user`, `service`, `uid`, `gid`, `system_user` and
  `create_home`, creates the service account `service_user` and its group, and
  adds the existing user `system_user` — here the operator — to that group.
  rkoshak's post above shows one.

## Role Variables

All variables are optional; the defaults are in
[`defaults/main.yml`](defaults/main.yml) and the full surface is validated by
[`meta/argument_specs.yml`](meta/argument_specs.yml).

| Variable | Default | Meaning |
| --- | --- | --- |
| `openhab_operator_user_name` | `link` | Existing login user added to the service account's group |
| `openhab_service_user_uid` | `9001` | UID and GID of the service account `openhab`, which owns the tree; openHAB in the container runs as the same IDs |
| `openhab_home` | `/opt/docker/openhab` | Root of `conf/`, `userdata/` and `addons/` |
| `openhab_conf_repo` | `""` | Git URL that seeds `conf/`; empty disables it |
| `openhab_conf_repo_branch` | `develop` | Branch checked out when `conf/` is seeded |
| `openhab_state_repo` | `""` | Git URL that seeds `userdata/`; empty disables it |
| `openhab_state_repo_branch` | `develop` | Branch checked out when `userdata/` is seeded |
| `openhab_git_user_name` | `""` | Name for commits made on the host |
| `openhab_git_user_email` | `""` | Email for commits made on the host |
| `openhab_version` | `latest` | Tag of the `openhab/openhab` image |
| `openhab_hostname` | `openhab` | Hostname of the container |
| `openhab_timezone` | `Europe/Berlin` | Time zone passed to the JVM |

**Upgrading from the single-repo layout.** `openhab_repo`, `openhab_repo_branch`
and `openhab_repo_force` are removed; setting `openhab_repo` fails the run with a
pointer here. `system_user` is now `openhab_operator_user_name`, and `openhab_uid`
is now `openhab_service_user_uid`.

## Two repositories: config and state

`openhab_home` holds two things with opposite ownership, and this role does not
treat them as one:

| Variable | Seeds | Source of truth |
| --- | --- | --- |
| `openhab_conf_repo` | `{{ openhab_home }}/conf` | the repo |
| `openhab_state_repo` | `{{ openhab_home }}/userdata` | the host |

`conf/` is declarative automation — items, rules, scripts, sitemaps. `userdata/`
is runtime state: thing status, jsondb, user sessions, and generated secrets
that rotate on their own. The state repository's root is the content of
`userdata/`.

### Seed once, never fetch

Both repositories are used only to *seed* an unseeded target. On a converged
host the role does no fetch at all — it only corrects a drifted `origin` URL,
which cannot touch the working tree. So:

- **The host needs no git credential in steady state.** Nothing authenticates
  to your git server on a normal run, and no private key belongs on the managed
  host.
- **Publishing new config is a deliberate operator step** — a manual pull — not
  something a deploy performs unannounced.
- **A populated tree can never be reset.** There is no code path that does it.

The two differ only in what counts as unseeded: `conf/` when it contains no
`.git`, `userdata/` when the *directory itself* is absent. That asymmetry is the
safety property — a `userdata/` that exists without a `.git` is a hand-built
host carrying the only copy of its runtime state, and seeding it would overwrite
exactly that.

A seed that fails — an unreachable server, a missing branch — leaves nothing
behind: `conf/` gets no `.git` and `userdata/` stays absent, so the next run
tries again. A seed that succeeds is an ordinary clone, with the full history
and its branch tracking `origin`, so the manual `git pull` and `git push` work
as on any checkout.

### What a seed needs

A seed is the one time the role talks to your git server, and the role brings
no credential of its own. Forward your SSH agent for the run that seeds:

```sh
ansible-playbook site.yml -e ansible_ssh_extra_args='-o ForwardAgent=yes'
```

`become` strips the forwarded agent from the environment, so the role picks it
up from the connecting user's session and hands it to `git fetch`. The git
server's host key is recorded on first contact and checked from then on
(`StrictHostKeyChecking=accept-new`). Without an agent that the server accepts,
the seed fails, leaves nothing behind, and is tried again on the next run.

Routine deploys fetch nothing and need no forwarding. Leave it off for them:
while a run lasts, root on the target can use a forwarded agent.

`addons/` stays role-created and unversioned.

### Operator identity

`openhab_git_user_name` / `openhab_git_user_email` write a `[user]` block into
`/root/.gitconfig` so host-side commits attribute to a person rather than
`root@<host>`. The role also registers both trees under `[safe] directory`,
without which git 2.35.2+ refuses to operate as root on a working tree owned by
the service user. The role's own git commands pass that exception on their
command line, so they work on service-owned trees from the first run, and under
`--check` too.

## Operator access

The operator — `openhab_operator_user_name`, a member of the service account's
group — edits `conf/` and runs git in both trees on the host. The role gives the
group read and write access to the whole tree (`u=rwX,g=rwX,o=`), and that
holds for what exists when it runs.

What is created later carries its creator's umask: a folder a checkout adds, or
git's own `objects/xx/`, comes out `755`, a file `644`. The openHAB image's
entrypoint hands the whole tree to the service account on every container start
and keeps each mode, so from then on the group could only read it, and the next
`git checkout` or `git reset` would fail with `Permission denied`.

So the role also sets a default ACL on `conf/` and `userdata/` that grants the
service account's group `rwX`. It survives the entrypoint's `chown` and makes
what is created below it group-writable from the start, whoever creates it —
the operator's git as much as openHAB itself. Setting it removes nothing,
ignored files included.

The ACL widens what the creating program allows; it never overrides it. A file
created `0600`, or narrowed later by a `chmod 644`, stays closed to the group
until the next role run. git creates with `0666` and `0777`, so the operator's
git is not affected. Until the next container start, what the operator creates
also belongs to the operator's primary group, which gets the same access — keep
that group private to the operator.

## Example Playbook

```yaml
- name: Run openHAB
  hosts: openhab
  become: true
  roles:
    - role: openhab
      vars:
        openhab_version: "5.1.2"
        openhab_conf_repo: git@git.example.com:home/openhab-conf.git
        openhab_state_repo: git@git.example.com:home/openhab-state.git
        openhab_git_user_name: Jane Doe
        openhab_git_user_email: jane@example.com
```

## Running the tests

Everything runs through one script, the same one CI calls. It needs
[uv](https://docs.astral.sh/uv/) and a Docker daemon your user can reach; uv
installs the pinned toolchain from `uv.lock` into `.venv/` on the first run,
and the script installs the collections `requirements.yml` pins into
`.ansible/collections/` — neither touches anything outside the checkout.

```sh
git clone https://github.com/xxthunder/ansible-role-openhab.git
cd ansible-role-openhab
scripts/test.sh        # yamllint, ansible-lint, then every Molecule scenario
scripts/test.sh lint   # the static checks only
```

What runs:

- **yamllint** and **ansible-lint** over the whole role.
- **`molecule/git-seeding`** — starts a Debian 12 container with bare
  repositories inside it as stand-in remotes, reached over `file://` and over
  ssh through an agent that holds the only key. It converges `tasks/git.yml`
  against a greenfield tree, a tree the service user owns that already holds
  config and live state, a seed that fails and is retried, a seed over ssh
  under `become`, and the superseded `openhab_repo`. It runs a second time to
  prove idempotence, then verifies that every greenfield tree was seeded as an
  ordinary clone while the populated one kept its local edit and its state. No
  network, no real git server, no real credentials. The container is removed at
  the end.
- **`molecule/operator-write`** — converges `tasks/permissions.yml` against
  trees the service account owns, with and without a state checkout. Then, as
  the operator with umask `022`, it commits new folders in both trees, runs the
  entrypoint's `chown -R`, and commits, switches branches and resets again. It
  also verifies that the role left every file in place, ignored ones included.

To look around in the scenario's container instead of tearing it down:

```sh
uv run molecule converge -s git-seeding   # create and converge, keep it running
uv run molecule login -s git-seeding      # shell inside the container
uv run molecule destroy -s git-seeding    # clean up
```

## License

MIT — see [LICENSE](LICENSE).
