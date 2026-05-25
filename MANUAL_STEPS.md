# Manual Steps Required

Here are the final manual steps to complete the setup.

---

### 1. Install Github CLI `dash` extension

This extension provides a nice dashboard for GitHub in your terminal.

```bash
gh extension install mislav/gh-dash
```

---

### 2. Install Tmux Plugins

For the tmux configuration to be fully functional, you need to install the plugins managed by `tpm` (Tmux Plugin Manager).

1.  Start a `tmux` session:
    ```bash
    tmux
    ```
2.  Inside tmux, press `CTRL-a` + `I` (capital 'i') to fetch the plugins.

---

### 3. Install Gemini CLI extensions

```bash
gemini extentions install @gemini-cli-extensions/conductor
gemini extentions install @gemini-cli-extensions/code-review
gemini extentions install @gemini-cli-extensions/security
gemini extentions install @gemini-cli-extensions/jules
```

---

### 4. Ensure worktrunk shell config

```bash
wt config shell install
```

### 5. OpenSpec agent config

```bash
openspec config profile
```

---

### 5. [Optional] Install Nix

If you plan to use `nix-shell` for per-project isolated environments, you can install Nix.

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```
