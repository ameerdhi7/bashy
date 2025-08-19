## Bashy

Automate front-end dev servers on macOS with:
- Keep-alive using PM2 (auto restart on crash)
- Local domain mapping via /etc/hosts
- Simple .bashy.env configuration
- Auto-add the embedded `bashy/` dir to your project's `.gitignore`

### Quick start

1) Make executable:
```bash
chmod +x ./bashy.sh
```

2) One-click setup and start:
```bash
./bashy.sh up \
  --name myapp \
  --port 5173 \
  --domain myapp.local \
  --workdir /absolute/path/to/your/project \
  --command "npm run dev -- --host 0.0.0.0 --port 5173"
```

This will:
- Copy `/absolute/path/to/your/project/.env.example` to `.env` if missing
- Ensure `PORT` and `HOST` in `.env` match your config
- Register `myapp.local` in `/etc/hosts` (prompts for sudo)
- Start or restart the dev server via PM2
- Add the `bashy/` directory to the target project's `.gitignore`

3) Alternatively, initialize then run step-by-step (example for a Vite/Vue app):
```bash
./bashy.sh init \
  --name myapp \
  --port 5173 \
  --domain myapp.local \
  --workdir /absolute/path/to/your/project \
  --command "npm run dev -- --host 0.0.0.0 --port 5173"
```

4) Register the local domain (requires sudo):
```bash
./bashy.sh register-domain
```

5) Start via PM2:
```bash
./bashy.sh start
```

Visit: `http://myapp.local:5173`

### Common commands

- `./bashy.sh status` Show PM2 status
- `./bashy.sh logs --follow` Tail PM2 logs
- `./bashy.sh restart` Restart via PM2
- `./bashy.sh stop` Stop via PM2
- `./bashy.sh delete` Remove from PM2
- `./bashy.sh save` Persist PM2 process list
- `./bashy.sh unregister-domain` Remove hosts entry

### `up` command

Run `./bashy.sh up` with or without flags. If `.bashy.env` exists, it uses it; otherwise it initializes one using provided flags or defaults. It then syncs `.env` with `PORT` and `HOST`, ensures the embedded `bashy/` folder is ignored by Git in your target project, registers the domain, and starts/restarts the service via PM2.

### Config reference (.bashy.env)

- `BASHY_NAME`: service/app name
- `BASHY_PORT`: port to expose
- `BASHY_DOMAIN`: local domain to map
- `BASHY_WORKDIR`: working directory to run in
- `BASHY_COMMAND`: command to start dev server
- `BASHY_ENV_EXTRA`: extra env as comma-separated `K=V` pairs

Environment exported to your command: `PORT`, `HOST`.


