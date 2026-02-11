This role installs the AnythingLLM Desktop AppImage for a single user, with desktop integration and command-line access.

## Features
- Downloads and installs the latest AnythingLLM AppImage to your user directory
- Adds a desktop launcher and command-line symlink (`anythingllm`)
- Uses `--no-sandbox` flag for compatibility (see [AppArmor workaround](https://askubuntu.com/a/1512288))

## Data Directory Note
AnythingLLM does **not** support changing its data directory via configuration. However, you can relocate your data by using a symlink. For example:

```sh
ln -s ~/Sync/AnythingLLM ~/.config/anythingllm-desktop
```

See [upstream issue #3087](https://github.com/Mintplex-Labs/anything-llm/issues/3087) for more details.
