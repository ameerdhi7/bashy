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

2) Simple spin up:
```bash
./bashy.sh up
```

This will:
- Copy `/absolute/path/to/your/project/.env.example` to `.env` if missing
- Ensure `PORT` and `HOST` in `.env` match your config
- Register `myapp.local` in `/etc/hosts` (prompts for sudo)
- Start or restart the dev server via PM2
- Add the `bashy/` directory to the target project's `.gitignore`

### Common commands

- `./bashy.sh status` Show PM2 status
- `./bashy.sh logs --follow` Tail PM2 logs
- `./bashy.sh restart` Restart via PM2
- `./bashy.sh stop` Stop via PM2
- `./bashy.sh delete` Remove from PM2
- `./bashy.sh save` Persist PM2 process list
- `./bashy.sh unregister-domain` Remove hosts entry

### `up` command

Run `./bashy.sh up`. It will use your project's `.env` for configuration (or reasonable defaults if `.env` is missing or empty). It then syncs `.env` with `PORT` and `HOST`, ensures the embedded `bashy/` folder is ignored by Git in your target project, registers the domain, and starts/restarts the service via PM2.

### Config reference (.env)

- `BASHY_NAME`: service/app name
- `BASHY_PORT`: port to expose
- `BASHY_DOMAIN`: local domain to map
- `BASHY_WORKDIR`: working directory to run in
- `BASHY_COMMAND`: command to start dev server
- `BASHY_ENV_EXTRA`: extra env as comma-separated `K=V` pairs

Environment exported to your command: `PORT`, `HOST`.


