This role installs the ElegooSlicer AppImage for a single user, with desktop integration and command-line access.

## Features
- Downloads and installs a pinned version of the ElegooSlicer AppImage to your user directory
- Adds a desktop launcher (with icon) and command-line symlink (`elegoo-slicer`)
- Associates `.stl`, `.sla` and `.3mf` files with the launcher

## libmspack workaround
The AppImage doesn't bundle `libmspack`, so it fails with
`error while loading shared libraries: libmspack.so.0: cannot open shared object file`
on systems that don't already have it installed (a known issue shared with the
upstream OrcaSlicer/BambuStudio AppImages, see
[OrcaSlicer#12918](https://github.com/OrcaSlicer/OrcaSlicer/issues/12918)).

Rather than installing `libmspack0t64` system-wide (which needs `sudo`), this role
fetches the `.deb` with `apt-get download` (uses your system's own apt sources, no
root or install required), extracts just the shared library with `dpkg-deb -x`, and
stores it under `{{ _install_dir }}/elegoo-slicer/libs`. The `elegoo-slicer` command
is a small wrapper script that sets `LD_LIBRARY_PATH` before launching the AppImage,
so nothing is installed outside this role's own directory.

## Updating the version
The AppImage filename embeds the version and target Ubuntu release (e.g. `Ubuntu2404`), so upgrading
requires bumping `_version` in `vars/main.yml` and, if ElegooSlicer drops support for the pinned Ubuntu
release, updating the filename in `tasks/main.yml` to match the new release assets:
https://github.com/elegoo-repo/ElegooSlicer/releases
