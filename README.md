
# npm-docker

A Windows batch script that runs `npm` commands inside Docker for complete isolation.  
Safe, host-agnostic, and ideal for monorepos, CI environments, legacy Windows setups, and Node version enforcement.

---

## Features

- Runs ALL npm commands in Docker, no local Node/npm required.
- Automatically detects `.nvmrc` and selects matching Node major version (e.g., `node:18-alpine`).
- Supports hoisted / shared `node_modules` in monorepos (Yarn, pnpm, Turborepo, Nx).
- Automatically mounts nearest `node_modules` to `/app/node_modules`.
- Supports blocklisted files through `.npm-docker-ignore`.
- Supports port forwarding using `.npm-docker-ports`.
- Pure Docker — no WSL or Node installations required.
- Can replace `npm.cmd` completely.

---

## Installation

1. Place `npm-docker.cmd` in a directory included in your `PATH`
   (e.g., `C:\npm-docker\`).
2. Optionally rename it to `npm.cmd` to fully replace the host `npm`.
3. Requires Docker installed and running.

---

## 🛠️ Usage Examples

```bash
npm-docker -v
npm-docker install
npm-docker run build
npm-docker run start
```

Or if renamed to `npm.cmd` (drop-in docker npm replacement):

```bash
npm install
npm run build
npm run start
```

---

## Monorepo Support (Hoisted node_modules)

If your `node_modules` is located **outside the project folder**,  
the script automatically searches parent directories and mounts the first one it finds into:

```
/app/node_modules
```


No configuration needed — automatic detection.

---

## Node Version Detection via `.nvmrc`

If `.nvmrc` exists, the script reads the **major version only**:

`.nvmrc`:
```
18.16.1
```

Script will automatically use:

```
node:18-alpine
```
No more need to manage node versions.

---

## Port Mapping

Create a `.npm-docker-ports` file in your project root:

```
3000
4200:4200
8080:80
```

---

## Ignoring Files
Do not expose your secrets to the internet.

Create `.npm-docker-ignore` to prevent mounting certain paths:

```
.env
dist
.secret-config
```

The script masks files/dirs using empty placeholders.

---

## Benefits

| Benefit | Description |
|---------|-------------|
| Safety | npm never touches your host — runs sandboxed in Docker |
| Consistency | Same Node version, same OS, same environment across all machines |
| Zero Host Pollution | No local Node, npm, or dependencies required |

---

## License

MIT License  
Created by Eldar Gerfanov.  
Use at your own risk.

---

## Tip

This script can fully **replace npm on Windows** — safer, cleaner, and portable.

```
rename npm-docker.cmd to npm.cmd
put it first in PATH
enjoy isolated npm everywhere
```

---

## Want to Improve It?

Pull requests welcome!

---

