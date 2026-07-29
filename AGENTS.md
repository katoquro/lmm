# AGENTS.md — creating `lmm` roles

Instructions for an AI agent (or human) adding a new role to this repo. Read
`README.adoc` first for the basics (`_user`, `_install_dir`, `_local_bin`,
shell variables). This file captures the concrete conventions and recipes
that aren't obvious from a single example.

## Naming and directory layout

- Role directory names are `<owner>.<name>` (or `sudo.<owner>.<name>`, see
  below). `<owner>` is just a namespace prefix identifying who
  contributed/maintains the role — `kato` in the existing roles is this
  repo's current maintainer's chosen prefix, nothing `lmm.sh` special-cases
  or validates. If you're adding your own role, use your own handle as the
  owner prefix instead of copying `kato` (e.g. `alice.k9s`); it's a naming
  convention, not a reserved keyword.
- The role directory name = the install command: `roles/<owner>.<name>` is
  installed with `lmm install <owner>.<name>`.
- The literal token `sudo.` at the front **is** meaningful — `lmm.sh`
  string-matches on it (`[[ "${role}" == "sudo."* ]]`, see `install()` in
  `lmm.sh`) and, only for matching roles, injects a play-level task that
  ensures `/etc/apt/keyrings` exists (needed before adding apt repos via
  `deb822_repository`, as in `roles/sudo.kato.terraform`).
  Prefix your role `sudo.<owner>.<name>` **only** if it uses `become: true`
  anywhere (apt installs, writing outside the user's home, etc) — this holds
  with no exceptions across all current roles: every `sudo.kato.*` role uses
  `become: true` and no `kato.*` role does. If a role never uses `become`, do
  not prefix it, even if it "feels" like a system package.
- `lmm.sh` does **not** actually gate installation on having an active sudo
  session. `check_sudo_session()` runs unconditionally for every role and
  only logs whether `sudo -n true` succeeds — it never blocks or exits based
  on that check. The real requirement is implicit: a `become: true` task
  simply fails at runtime if there's no active session (ansible-playbook runs
  non-interactively, so it can't prompt for a password), and `install()`'s
  generic failure handler then prints "If ROLE requires sudo. You have to run
  'sudo true' before calling 'lmm install'" as a diagnostic hint. In practice:
  always run `sudo true` first when testing a `sudo.*` role, but don't assume
  `lmm.sh` enforces this for you.
- Standard files per role:
  - `roles/<name>/tasks/main.yml` — required.
  - `roles/<name>/vars/main.yml` — only if there's a real variable (e.g. a
    pinned version). Don't create it just to hold a constant that's only used
    once — inline the literal in the task instead (see "Constants vs vars"
    below).
  - `roles/<name>/readme.md` — short human-readable description: what it
    installs, any non-obvious workaround, how to bump the version.
  - No `meta/main.yml`, no role registry file to update elsewhere — `lmm.sh`
    discovers roles by directory listing (`ls roles/`) and tests iterate the
    same way. Adding the directory is the whole registration step.

## Picking a pattern

### 1. Prebuilt binary/tarball from a GitHub release, "latest" is fine
Use `releases/latest/download/<fixed-filename>` — GitHub redirects it to the
current release, so no version variable is needed.
```yaml
- name: download and install
  unarchive:
    src: "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz"
    dest: "/home/{{ _user }}/.local/bin"
    include: [k9s]
    remote_src: yes
```
(see `roles/kato.k9s`, `roles/kato.acorn`)

### 2. Versioned release where the filename embeds the version
GitHub's `releases/latest/download/` trick doesn't work when the asset
filename itself contains the version (e.g.
`ElegooSlicer_Linux_Ubuntu2404_V1.5.2.2.AppImage`). Pin the version in
`vars/main.yml` instead:
```yaml
# vars/main.yml
_version: "1.5.2.2"
```
```yaml
# tasks/main.yml
- name: Download
  ansible.builtin.get_url:
    url: "https://github.com/org/repo/releases/download/v{{ _version }}/App-{{ _version }}.AppImage"
    dest: "{{ _install_dir }}/appname/App.AppImage"
    mode: "u+x"
```
(see `roles/kato.obsidian-md`, `roles/kato.curlie`, `roles/sudo.kato.insomnia`)

### 3. AppImage with desktop integration
Standard shape, no sudo required:
1. `file` → create `{{ _install_dir }}/<app>/` directory, `register` it.
2. `get_url` the AppImage into that dir with `mode: "u+x"`.
3. `file` (state: link) → symlink it (or a wrapper script, see below) into
   `{{ _local_bin }}/<command-name>`.
4. Desktop icon + launcher:
   - If the upstream **source repo** (not the AppImage) ships a plain PNG/SVG
     icon asset (check `resources/images/` or similar on GitHub first), just
     `get_url` it straight into `~/.local/share/icons/`. This is preferred —
     no need to extract or run the AppImage at all.
   - Only fall back to `--appimage-extract` (see `roles/kato.obsidian-md`) if
     no static icon asset exists upstream. That pattern runs the AppImage
     once to extract its bundled `.desktop`/icon files with
     `ansible.builtin.find` (pattern `*.desktop`) since the exact filename
     inside the package isn't knowable in advance.
   - Write the `.desktop` file with `ansible.builtin.copy` + inline `content:`
     (see `roles/kato.anythingllm`), pointing `Exec=` at the `_local_bin`
     command and `Icon=` at the downloaded/extracted icon path.
5. Electron/Chromium-based AppImages (Obsidian, AnythingLLM) usually need
   `--no-sandbox` in `Exec=` because of AppArmor restrictions on the
   `chrome-sandbox` setuid helper
   (https://askubuntu.com/a/1512288). **Native C++/Qt/wxWidgets apps don't
   have this problem and don't take this flag** — check what the app is
   built with before copying the flag over. Passing an unrecognized flag to
   a native app's arg parser can make it refuse to start.

### 4. System package requiring root (apt repo, .deb, etc)
Must live under `sudo.kato.<name>`. Use `become: true` on every task that
needs it — see `roles/sudo.kato.terraform` (adds an apt repo via
`deb822_repository` then `apt: pkg: [...]`) or `roles/sudo.kato.insomnia`
(installs a versioned `.deb` directly via `apt: deb: <url>`).

### 5. Missing shared library, without installing anything system-wide
Some AppImages don't bundle every `.so` they link against (known upstream
issue for the OrcaSlicer/BambuStudio/ElegooSlicer family and `libmspack`,
see https://github.com/OrcaSlicer/OrcaSlicer/issues/12918). Rather than
`apt install`-ing the library system-wide (which forces the role under
`sudo.kato.*`), fetch just the `.deb` and extract only the `.so` into the
role's own directory, then load it via `LD_LIBRARY_PATH` in a wrapper script:

```yaml
- name: Download package via apt (no install)
  ansible.builtin.command:
    argv: ["apt-get", "download", "libfoo0"]
    chdir: "{{ __install_dir.path }}/tmp"
  changed_when: true
```
`apt-get download` fetches a `.deb` using the system's already-configured apt
sources, **without root and without installing it** — no need to hardcode a
mirror URL or a version number.

Then extract with `dpkg-deb -x <deb> <dir>` (also doesn't need root), find
the shared library, and copy it into `{{ _install_dir }}/<app>/libs/`.

**Pitfall:** shared libraries are typically shipped as a real file plus a
SONAME symlink (e.g. `libfoo.so.0 -> libfoo.so.0.1.0`), and it's the *symlink
name* the dynamic linker actually looks up. `ansible.builtin.find` defaults
to `file_type: file`, which **silently skips symlinks** — you'll only get the
versioned file and the app will still fail to load. Always pass
`file_type: any` when hunting for `.so*` files this way. `ansible.builtin.copy`
with `remote_src: true` dereferences a symlink source into a real file at the
destination, which is fine — the loader just needs a file with the right name.

Finally, don't symlink `_local_bin/<command>` straight to the AppImage
anymore — point it at a small wrapper script instead, so `LD_LIBRARY_PATH` is
set before exec:
```yaml
- name: Create launch wrapper script
  ansible.builtin.copy:
    dest: "{{ __install_dir.path }}/app-wrapper.sh"
    mode: '0755'
    content: |
      #!/usr/bin/env bash
      export LD_LIBRARY_PATH="{{ __install_dir.path }}/libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec "{{ __install_dir.path }}/App.AppImage" "$@"

- name: Create symlink for command-line access
  ansible.builtin.file:
    src: "{{ __install_dir.path }}/app-wrapper.sh"
    dest: "{{ _local_bin }}/app"
    state: link
```
(see `roles/kato.elegoo-slicer/tasks/libmspack.yml`)

## Constants vs vars

Put something in `vars/main.yml` only if it's a genuine variable — a pinned
version the maintainer will bump later, or a value reused in several places.
A one-off constant like a package name used in a single task should just be
inlined literally in the task. Don't create a variable purely to "name" a
value if nothing about the role would need to change per-invocation.

## Splitting a role into multiple task files

If a role accumulates a distinct, self-contained chunk of logic (e.g. "make
sure this one missing dependency is available"), pull it into its own
`tasks/<topic>.yml` and pull it in with:
```yaml
- name: Install bundled libfoo dependency
  ansible.builtin.include_tasks: libfoo.yml
```
Tasks in the included file still see variables registered earlier in the
parent file (e.g. `__install_dir`) — no need to re-pass them explicitly.

## Before calling a role done

1. Validate YAML: `python3 -c "import yaml; yaml.safe_load(open('roles/<name>/tasks/main.yml'))"`
   for every new/changed file.
2. `ansible-lint roles/<name>` — expect exactly one pre-existing warning
   (`role-name` pattern, because role directories use dots) and nothing else.
   Any other finding is real.
3. Don't run `./lmm.sh install <name>` directly on your own (or the user's)
   machine to test — it mutates the real system: installs packages, may run
   `become: true`/apt, writes into `~/.local`. Use the disposable Docker
   harness instead: `./lmm.sh test <name>` (see `test()` in `lmm.sh`). It
   builds (once, cached locally as the `lmm-base` image) an Ubuntu 24.04
   container from `test/Dockerfile` with a passwordless-sudo user, bind-mounts
   `roles/`, `lmm.sh` and `test/test.sh` into it, and runs `test/test.sh`
   inside it — which does `sudo true` then `./lmm.sh install <name>`. The
   container is started with `--rm`, so everything the install writes
   (packages, `~/.local`, etc) disappears with it; only your host `roles/`
   directory is shared in, and nothing in this flow writes back to it. This
   needs Docker installed (`lmm install kato.docker` if it isn't). Omitting
   `<name>` (`./lmm.sh test`) installs *every* role in the repo instead of
   just yours — don't do that for a quick iteration loop.
4. The test container is headless (no display server, no GPU/libGL), so it
   can confirm the Ansible itself completes cleanly (templating, downloads,
   `become` escalation, idempotency) but **cannot** confirm a GUI app
   actually launches. That's an inherent gap, not something to work around
   by installing on a real desktop yourself — if a GUI smoke-test is truly
   needed, that's the user's call to make on their own machine, not a step
   to take unprompted.
