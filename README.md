openhab
=========

> **Lineage.** This repository began as a fork of
> [`fex01/ansible-openhab`](https://github.com/fex01/ansible-openhab) and has
> permanently diverged: it is maintained under `xxthunder` on its own release
> lineage and does not track upstream. Attribution to the original author, and
> to rkoshak's post below, stands — this note is about lineage, not credit.
>
> Development conventions, testing and the release process are in
> [AGENTS.md](AGENTS.md); work is tracked in [docs/backlog/](docs/backlog/).


This role will set up an openHAB server as Docker container and is heavily inspired by [rkoshak](https://github.com/rkoshak)s post [Ansible Revisited](https://community.openhab.org/t/ansible-revisited/105754) in the [openHAB community](https://community.openhab.org).

**Work In Progress**: `molecule/default` is rudimentary; the focused
`molecule/git-seeding` scenario is the one that proves current behaviour.


### It will
- create an openHAB service account
- add the system user to the openHAB service group
- if configured: seed `conf/` and `userdata/` from two separate git repositories
- create missing folders & set permissions
- pull the latest openHAB image and recreate the container if it changed

Role Variables
--------------

`openhab/defaults/main` contains variables which should be overwritten to customize this role:
```yml
# to be added to the openhab user group
system_user: link
# openhab user ID
openhab_uid: 9001
# root directory of openhab data
openhab_home: /opt/docker/openhab
# openHAB config repository [optional]
# Authentication has to be resolved beforehand, one option would be SSH Key 
# Authentication.
# Example: ssh://{{ system_user }}@git.example.com:port/path/to/repo/openhab.git
# NOTE: superseded -- see "Two repositories" below.
openhab_repo:
# which branch?
openhab_repo_branch: master
# should local changes be discarded?
openhab_repo_force: yes
# which openHAB version should be pulled from Docker?
openhab_version: latest
# Docker container hostname
openhab_hostname: openhab
# TimeZone: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
openhab_timezone: Europe/Berlin
```

Requirements
------------

- [git](https://git-scm.com) - might be installed & configured via [weareinteractive.git](https://github.com/weareinteractive/ansible-git)
- [OpenSSH Server](https://www.openssh.com) - might be installed via [weareinteractive.apt](https://github.com/weareinteractive/ansible-apt)
- [Docker](https://www.docker.com) - might be installed via [geerlingguy.docker_arm](https://github.com/geerlingguy/ansible-role-docker_arm)

Dependencies
------------

- *create-service-account*: a role copied from [rkoshak](https://github.com/rkoshak)s post [Ansible Revisited](https://community.openhab.org/t/ansible-revisited/105754) in the [openHAB community](https://community.openhab.org):
  ```yml
  ---
  # tasks file for create-service-account

  - name: "Create {{ service_user }} group so we can control the gid"
    group:
      gid: "{{ gid }}"
      name: "{{ service_user }}"
      state: present
      system: True
    become: True

  - name: "Create {{ service_user }} user"
    user:
      comment: "{{ service }} service"
      createhome: "{{ create_home }}"
      group: "{{ service_user }}"
      name: "{{ service_user }}"
      shell: /usr/sbin/nologin
      state: present
      system: True
      uid: "{{ uid }}"
    become: True

  - name: "Add {{ system_user }} to the {{ service_user }} group"
    user:
      append: True
      groups: "{{ service_user }}"
      name: "{{ system_user }}"
    become: True
  ```

Example Playbook
----------------
This role is only one step in setting up a new server - if you have already a prepared server the following play would be enough:

```yml
- name: Playbook to add an openHAB Docker image
  hosts: openhab
  debugger: on_failed
  become: true

  tasks:
  - include_role: 
      name: openhab
```

If you have to setup a server from scratch the following play might give you a hint about which steps are needed:

```yml
# invoke with `ansible-playbook openhab-play.yml --vault-id openhab@prompt`

- name: Playbook to set up an openHAB server on a Raspberry Pi
  hosts: openhab
  gather_facts: false
  debugger: on_failed
  become: true

  tasks:
    # * rename the default user *pi* to *user_name*
    # * set a new user password *user_password*
    # * rename the home dir */home/{{ user_name_old }}* to */home/{{ user_name_new }}*
    # * create a symlink */home/{{ user_name_old }}* linking to */home/{{ user_name_new }}*
    # * change the hostname to *host_name*
    # * configure locale
    # * set timezone to *localization_timezone*
    # * activate auto-updates / -upgrades
    # * install and configure vim
    # * set sensible defaults for the SSH server
    # * write public SSH keys to *user_name*'s *authorized_keys* file
    # * install and configure a firewall (ufw)
    - include_role: 
        name: prepare-raspberry
    # open ports necessary for openHAB
    - include_role:
        name: weareinteractive.ufw
      vars:
        ufw_rules: "{{ openhab_ufw_rules }}"
    # install & configure git
    - include_role:
        name: "weareinteractive.git"
      vars:
        git_config:
          user:
            name: "{{ git_commit_user_name }}"
            email: "{{ git_commit_user_email }}"
    # install pip (requirement for docker_arm)
    - include_role: 
        name: geerlingguy.pip
    # install docker
    - include_role: 
        name: geerlingguy.docker_arm
    # reboot
    - include_role: 
        name: GROG.reboot
    # install openHAB
    - include_role:
        name: "openhab"
      vars:
        system_user: "{{ user_name }}"
    # install the Web-Log-Viewer also used in openHABian 
    - include_role:
        name: "frontail"
    # reduce SD Card wear
    - include_role:
        name: "minimize-writes"
    # create SMB share for the openHAB configuration
    - include_role:
        name: "bertvv.samba"
    # I use this Raspberry only for openHAB -> when I SSH onto the server, I almost always want to go to the openHAB folder
    - name: SSH into openHAB folder
      blockinfile:
        path: /home/{{ user_name }}/.bashrc
        block: |
          # on login jump to openhab directory
          cd {{ openhab_home }}
```
- the prepare-raspberry role can be found as part of my [ansible-gitserver](https://github.com/fex01/ansible-gitserver) repo
- *minimize-writes*: a role copied from [rkoshak](https://github.com/rkoshak)s post [Ansible Revisited](https://community.openhab.org/t/ansible-revisited/105754) in the [openHAB community](https://community.openhab.org):
  ```yml
  ---
  # tasks file for minimize-writes
  # http://www.zdnet.com/article/raspberry-pi-extending-the-life-of-the-sd-card

  - name: Mount /tmp to tmpfs
    mount:
      path: "{{ item.path }}"
      src: tmpfs
      fstype: tmpfs
      opts: defaults,noatime,nosuid,size={{ item.size }}
      dump: "0"
      state: mounted
    loop:
      - { "path": "/tmp", "size": "100m" }
      - { "path": "/var/tmp", "size": "30m" }
      - { "path": "/var/log", "size": "100m" }
    register: mounted
    become: True

  - name: Reboot if changed
    include_role:
      name: GROG.reboot
    when: mounted.changed
  ```


License
-------

MIT


Two repositories: config and state
----------------------------------

openHAB's `openhab_home` holds two things with opposite ownership, and this
role no longer treats them as one:

| Variable | Seeds | Source of truth |
| --- | --- | --- |
| `openhab_conf_repo` | `{{ openhab_home }}/conf` | the repo |
| `openhab_state_repo` | `{{ openhab_home }}/userdata` | the host |

`conf/` is declarative automation — items, rules, scripts, sitemaps. `userdata/`
is runtime state: thing status, jsondb, user sessions, and generated secrets
that rotate on their own. A single repo forced them to share one policy, and
`openhab_repo_force: yes` applied that policy to the whole tree, so every deploy
discarded runtime state. **`openhab_repo`, `openhab_repo_branch` and
`openhab_repo_force` are removed**; setting `openhab_repo` now fails the run
with a pointer here rather than silently doing nothing.

### Seed once, never fetch

Both repositories are used only to *seed* an unseeded target. On a converged
host the role does no fetch at all — it only corrects a drifted `origin` URL,
which cannot touch the working tree. Consequences worth being explicit about:

- **The host needs no git credential in steady state.** Nothing authenticates
  to your git server on a normal run, so no private key belongs on the managed
  host. (An earlier version of this role passed `key_file` pointing at one; that
  is gone.)
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

### Testing

`molecule/git-seeding` covers this wiring end to end against bare repositories
created inside the container, so it needs no network, no git server and no
credentials:

```sh
molecule test -s git-seeding
```

`molecule/default` remains rudimentary and is not part of this scenario.
