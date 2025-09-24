# Ghostty Config – Git Sync Helper

This repo lets you **version**, **push**, and **pull** your [Ghostty](https://ghostty.org/) terminal config using Git.  
It includes a helper script `gh.sh` to keep your local Ghostty config and the repo in sync,
plus a convenience action to **reload** Ghostty after changes.

---

## What it does

- **Push**: Copies your local Ghostty `config` file into the repo at `ghostty/config`, commits, and **force pushes**.
- **Pull**: Pulls the latest repo changes and installs them to your local Ghostty config (creates a timestamped backup).
- **Diff**: Shows the differences between the repo’s `ghostty/config` and your local config.
- **Install (symlink)**: Replaces your local config with a symlink to the repo’s tracked file.
- **Reload**: Best-effort reload/restart of Ghostty (macOS via AppleScript; Linux via SIGHUP/start).

> **Note:** Force-push is used intentionally for a personal dotfiles flow.  
> If you collaborate with others, consider switching to `--force-with-lease` in `gh.sh`.

---

## Paths

- **Repo path (tracked file):** `ghostty/config`
- **Local Ghostty config:**
  - macOS: `~/Library/Application Support/com.mitchellh.ghostty/config`
  - Linux: `~/.config/ghostty/config`

You can override either path via environment variables (see **Configuration**).

---

## Quick Start

1. Clone this repo.
2. Make the helper script executable:
   ```bash
   chmod +x ./gh.sh
   ```
3. First push (copy local → repo and publish):
   ```bash
   ./gh.sh push
   ```
4. Later, apply repo changes locally:
   ```bash
   ./gh.sh pull
   ```
5. (Optional) Symlink instead of copying:
   ```bash
   ./gh.sh install
   ```
6. Reload Ghostty after changes:
   ```bash
   ./gh.sh reload
   ```

---

## Commands

```text
./gh.sh push     # copy local → repo, commit, FORCE push
./gh.sh pull     # fetch/pull repo → install locally (backup made)
./gh.sh diff     # show diff between repo and local config
./gh.sh install  # symlink repo file into local Ghostty config path
./gh.sh reload   # best-effort reload/restart of Ghostty
```

---

## Configuration

You can override defaults by exporting environment variables (e.g., in your shell or CI):

- `REPO_GHOSTTY_PATH` — path (inside the repo) to store the config.  
  Default: `ghostty/config`
- `GIT_REMOTE` — git remote name.  
  Default: `origin`
- `GIT_BRANCH` — target branch to push/pull.  
  Default: `main`
- `GHOSTTY_CONFIG_PATH` — absolute path to your local Ghostty `config`.  
  Defaults to OS-appropriate path listed above.

Example:
```bash
export REPO_GHOSTTY_PATH="ghostty/config"
export GIT_REMOTE="origin"
export GIT_BRANCH="main"
export GHOSTTY_CONFIG_PATH="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
```

---

## Optional: Make it runnable from anywhere

Add a tiny wrapper to your `$PATH` (e.g., `~/bin/gh`):

```bash
#!/usr/bin/env bash
# change this to your repo’s absolute path
REPO="$HOME/path/to/your/ghostty-config-repo"
cd "$REPO" || exit 1
exec ./gh.sh "$@"
```

Then:
```bash
chmod +x ~/bin/gh
gh push
```

---

## Troubleshooting

- **“unbound variable” / syntax errors**  
  The script sets safe defaults. If you still see parse errors on macOS:
  ```bash
  bash -n ./gh.sh
  sed -i '' 's/
$//' ./gh.sh   # convert to Unix newlines if needed
  ```

- **Protected branch / push rejected**  
  The script uses `git push --force`. If branch protection blocks it, either:
  - Temporarily lift protection, or
  - Change to `--force-with-lease` in `gh.sh`, or
  - Push to a different branch (`export GIT_BRANCH=my-branch`).

- **Ghostty doesn’t pick up changes**  
  Use `./gh.sh reload`. If that doesn’t apply changes, quit/reopen Ghostty.

---

## .gitignore suggestion

Backups are named like `config.bak-YYYYMMDD-HHMMSS`. You can ignore them globally:
```gitignore
*.bak-2*
```

---

## Theme Cheatsheet 🎨

Ghostty supports themes both in your main `config` and as standalone `.theme` files.

### Store a custom theme

1. Create folder (if missing):
   - macOS: `~/Library/Application Support/com.mitchellh.ghostty/themes/`
   - Linux: `~/.config/ghostty/themes/`

2. Save `banana-blueberry.theme` inside it:
   ```ini
   # Banana Blueberry (custom theme)
   background = #1E0449
   foreground = #B2EC61
   selection-background = #014D3A
   selection-foreground = #f4f4f4
   cursor-color = #e07d13
   cursor-style = bar
   cursor-style-blink = false

   palette = 0=#17141f
   palette = 1=#ff6b7f
   palette = 2=#00bd9c
   palette = 3=#e6c62f
   palette = 4=#22e8df
   palette = 5=#dc396a
   palette = 6=#56b6c2
   palette = 7=#f1f1f1
   palette = 8=#495162
   palette = 9=#fe9ea1
   palette = 10=#98c379
   palette = 11=#f9e46b
   palette = 12=#91fff4
   palette = 13=#da70d6
   palette = 14=#bcf3ff
   palette = 15=#ffffff
   ```

3. In your main `ghostty/config`:
   ```ini
   theme = Banana Blueberry
   ```

---

### Useful commands

```bash
ghostty +list-themes                   # show all built-in + custom themes
ghostty +set theme="Banana Blueberry"  # switch theme live
ghostty +toggle theme                  # toggle between light/dark pair
```

---

### Keybind examples

```ini
# Toggle between light/dark (if both are defined)
keybind = cmd+shift+t=toggle_theme

# Cycle through specific themes
keybind = cmd+alt+t=cycle_theme:Solarized Dark,Catppuccin Mocha,Rose Pine

# Quick set to Banana Blueberry
keybind = cmd+alt+b=set_theme:Banana Blueberry
```

---

## License

MIT. Use at your own risk.
