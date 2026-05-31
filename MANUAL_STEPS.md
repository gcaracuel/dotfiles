# Manual Steps Required

Here are the final manual steps to complete the setup.

---

### 1. Configure Raycast Window Switcher

After Raycast is installed, set up the Option+W hotkey for switching between apps:

1. Open Raycast (it should launch automatically after install, or press Command+Space and search for Raycast)
2. Press `Command + ,` to open Raycast Preferences
3. In the left sidebar, click on **Extensions**
4. Find **"Window Management"** in the list
5. Click on the extension, then find the **"Search Windows"** command
6. Click the hotkey field next to it and press `Option + W` to assign the hotkey
7. Close preferences

Now `Option + W` will open a window switcher showing all open windows across all apps!

---

### 2. Install Github CLI `dash` extension

This extension provides a nice dashboard for GitHub in your terminal.

```bash
gh extension install mislav/gh-dash
```

### 2. Disable Github CLI telemetry

```bash
gh config set telemetry disabled
```

---

### 3. Install Tmux Plugins

For the tmux configuration to be fully functional, you need to install the plugins managed by `tpm` (Tmux Plugin Manager).

1.  Start a `tmux` session:
    ```bash
    tmux
    ```
2.  Inside tmux, press `CTRL-a` + `I` (capital 'i') to fetch the plugins.

---

### 4. Ensure worktrunk shell config

```bash
wt config shell install
```

---

### 5. [Optional] Install Nix

If you plan to use `nix-shell` for per-project isolated environments, you can install Nix.

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```
