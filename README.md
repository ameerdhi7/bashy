## Bashy

Automate front-end dev servers on macOS with:
- Keep-alive across restarts via LaunchAgent
- Local domain mapping via /etc/hosts
- Simple .bashy.env configuration

### Quick start

1) Make executable:
```bash
chmod +x ./bashy.sh
```

2) Initialize config (example for a Vite/Vue app):
```bash
./bashy.sh init \
  --name myapp \
  --port 5173 \
  --domain myapp.local \
  --workdir /absolute/path/to/your/project \
  --command "npm run dev -- --host 0.0.0.0 --port 5173"
```

3) Register the local domain (requires sudo):
```bash
./bashy.sh register-domain
```

4) Install and start the LaunchAgent:
```bash
./bashy.sh install
```

Visit: `http://myapp.local:5173`

### Common commands

- `./bashy.sh status` Show status
- `./bashy.sh logs --follow` Tail logs
- `./bashy.sh restart` Restart service
- `./bashy.sh stop` Stop service
- `./bashy.sh uninstall` Remove LaunchAgent
- `./bashy.sh unregister-domain` Remove hosts entry

### Config reference (.bashy.env)

- `BASHY_NAME`: service/app name
- `BASHY_PORT`: port to expose
- `BASHY_DOMAIN`: local domain to map
- `BASHY_WORKDIR`: working directory to run in
- `BASHY_COMMAND`: command to start dev server
- `BASHY_ENV_EXTRA`: extra env as comma-separated `K=V` pairs

Environment exported to your command: `PORT`, `HOST`.


