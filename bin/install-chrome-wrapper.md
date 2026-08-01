# Installing chrome-wrapper (instructions for an AI agent)

You are an agent installing `chrome-wrapper` for your user. Follow these steps in order.
Two of them you cannot do yourself — the doc tells you exactly where to stop and what to
hand back to the user.

`chrome-wrapper` manages persistent, isolated Chrome **identities**: one identity = one set
of logins, with its own profile directory, its own fixed CDP port, and its own macOS app
bundle. You (the agent) drive it via `agent-browser --cdp`.

## 0. Preconditions — check, don't assume

```bash
[ "$(uname)" = Darwin ] || echo "STOP: macOS only"
[ -d "/Applications/Google Chrome.app" ] || echo "STOP: needs Google Chrome at /Applications"
command -v git >/dev/null || echo "STOP: needs git"
```

If any STOP prints, report it to the user and go no further. Optional but recommended:
`python3` (seeds quiet default preferences; without it new identities start with Chrome's
defaults) and Python `PIL` (generates identity icons; without it, no icon — everything else
works).

## 1. Clone and link

```bash
git clone https://github.com/ssv445/claude-skills.git ~/code/claude-skills
mkdir -p ~/.local/bin
ln -s ~/code/claude-skills/bin/chrome-wrapper ~/.local/bin/chrome-wrapper
```

If the repo is already cloned somewhere, reuse it — but the symlink must live at exactly
`~/.local/bin/chrome-wrapper`. That path is hardcoded: every per-identity command the tool
creates points back into `~/.local/bin`, so a symlink anywhere else leaves them dangling.

Verify `~/.local/bin` is on PATH:

```bash
case ":$PATH:" in *":$HOME/.local/bin:"*) echo ok ;; *) echo "STOP: ~/.local/bin not on PATH" ;; esac
```

If not on PATH, add it to the user's shell profile (`~/.zshrc` on macOS:
`export PATH="$HOME/.local/bin:$PATH"`) and tell the user you did so.

## 2. Install the driver

`agent-browser` is the CLI that drives identities over CDP. Check for it, install if missing:

```bash
command -v agent-browser || npm install -g agent-browser
agent-browser --version
```

## 3. Create the first identity — THIS STEP IS THE USER'S

`chrome-wrapper new` refuses to run without a human at a terminal, by design: it opens a
browser window that only your user can sign into. **Do not try to work around this.** No
scripted TTY, no expect, no pasting credentials. If you have the user's passwords, you
should not, and this tool is built so you never need them.

Hand the user this, with a name that matches how they'll use it (their name, a company,
a project — one identity per set of logins):

```
Run this in your terminal:

  chrome-wrapper new personal --label "Personal"

A new Chrome window will open. Sign into the accounts this identity should hold.
When you're done, tell me — I can use it from then on.
```

## 4. Verify

After the user confirms:

```bash
chrome-wrapper list                                    # identity, port, running state
agent-browser --cdp $(chrome-wrapper-personal --port) eval "document.title"
```

If the eval returns a page title, the install is complete. If it returns an error, run
`chrome-wrapper-personal` first (the identity may be stopped — `--port` reads the registry,
it does not launch).

## Rules for you, the agent, from now on

- **The port is the identity.** Always reach an identity via
  `agent-browser --cdp $(chrome-wrapper-<name> --port)`. Never point automation at the
  user's own Chrome, and never guess a port number.
- A wrong identity shows up as a logged-out browser. That is a signal to stop and ask —
  never to silently fall back to another identity or another browser.
- One account lives in exactly one identity. If you find the same account signed into two,
  tell the user; it breaks the safety property above.
- `new` and `rm` always need the user at a terminal. Ask; don't work around.
- Need a login the identity doesn't have? Ask the user to sign in once in that identity's
  window. Never handle credentials yourself.
