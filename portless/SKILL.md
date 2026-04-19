---
name: portless
description: Set up and use portless for named local dev server URLs (e.g. http://myapp.localhost instead of http://localhost:3000). Use when integrating portless into a project, configuring dev server names, setting up the local proxy, working with .localhost domains, or troubleshooting port/proxy issues.
---

# Portless

Replace port numbers w/ stable, named `.localhost` URLs.

## Installation

Global CLI only. No project dependency, no `npx`.

```bash
npm install -g portless
```

## Usage

```bash
portless proxy start                # start proxy (port 1355, no sudo)
portless myapp next dev             # -> http://myapp.localhost:1355
portless api.myapp pnpm start       # -> http://api.myapp.localhost:1355
portless docs.myapp next dev        # -> http://docs.myapp.localhost:1355
```

Proxy auto-starts when you run an app.

### package.json integration

```json
{
  "scripts": {
    "dev": "portless myapp next dev"
  }
}
```

### Bypass

`PORTLESS=0` or `PORTLESS=skip` → runs command directly without proxy.

## How It Works

1. `portless proxy start` → HTTP reverse proxy on port 1355 (configurable w/ `-p` or `PORTLESS_PORT`)
2. `portless <name> <cmd>` → assigns random free port (4000-4999) via `PORT` env var, registers w/ proxy
3. Browser hits `http://<name>.localhost:1355` → proxy forwards to app's port

`.localhost` resolves to `127.0.0.1` natively on macOS/Linux — no `/etc/hosts` needed.

Most frameworks respect `PORT`. For those that don't (Vite, Astro, React Router, Angular), portless auto-injects `--port` and `--host` flags.

## CLI Reference

| Command                             | Description                                                   |
| ----------------------------------- | ------------------------------------------------------------- |
| `portless <name> <cmd> [args...]`   | Run app at `http://<name>.localhost:1355` (auto-starts proxy) |
| `portless list`                     | Show active routes                                            |
| `portless trust`                    | Add local CA to system trust store (for HTTPS)                |
| `portless proxy start`              | Start proxy as daemon (port 1355, no sudo)                    |
| `portless proxy start --https`      | Start w/ HTTP/2 + TLS (auto-generates certs)                  |
| `portless proxy start -p <number>`  | Start proxy on custom port                                    |
| `portless proxy start --foreground` | Start proxy in foreground (debugging)                         |
| `portless proxy stop`               | Stop proxy                                                    |
| `portless <name> --force <cmd>`     | Override existing route from another process                  |
| `portless --help` / `-h`            | Show help                                                     |
| `portless --version` / `-v`         | Show version                                                  |

## Troubleshooting

- **Proxy not running** — auto-starts w/ app. Manual: `portless proxy start`
- **Port in use** — `portless proxy start -p 8080`
- **Framework ignoring PORT** — portless auto-injects for Vite/Astro/React Router/Angular. Others: pass `--port $PORT` manually.
- **508 Loop Detected** — set `changeOrigin: true` in proxy config when dev server proxies to another portless app.
