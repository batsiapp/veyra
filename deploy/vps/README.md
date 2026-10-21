# Running Veyra on a Linux VPS

This runs the whole stack on one Ubuntu or Debian VPS, MetaTrader 4 included.
No Mac, domain name, or Cloudflare account is needed.

| Piece | Runs as | Reachable from |
| --- | --- | --- |
| Veyra service | Docker (`veyra`) | the VPS only (`127.0.0.1:8080`) |
| PostgreSQL 17 | Docker (`postgres`) | the private Docker network only |
| Console (web dashboard) | Docker (`console`) | the VPS only (`127.0.0.1:3000`) |
| Outage watchdog | Docker (`watchdog`) | nothing; it only sends alerts |
| MT4 under Wine, with a browser view of its screen | Docker (`mt4`) | the VPS only (`127.0.0.1:6080`) |

Nothing listens on the internet. You reach the console and the MT4 screen from
your own computer through an SSH tunnel. The MT4 add-on reaches Veyra over the
private Docker network at `http://172.30.0.20/ea/poll`. That is a relay in the
`mt4` container, because MT4 can only call port 80 and Veyra listens on 7801.

## What you need

- A VPS with **Ubuntu 22.04/24.04 or Debian 12/13**, x86-64, and SSH access.
  The minimum is **1 GB of RAM** with the 2 GB swap file the setup script
  adds; 2 GB of RAM is more comfortable.
- A **broker account that supports MT4**. Start with a **demo** account.
- A GitHub **personal access token** that can read `batsiapp/veyra` and its
  packages. A classic token with the `repo` and `read:packages` scopes works.
- An API key for the AI model, for example from OpenRouter. It's only needed
  for automatic trading, so you can add it later.

## 1. Build the images (once, then after every update)

GitHub Actions builds the three images (`veyra-service`, `veyra-console`,
`veyra-mt4`) on every push to `main` and publishes them to
`ghcr.io/batsiapp/...`. Check the **Images** workflow under the repository's
**Actions** tab. It must finish green before the VPS can pull anything.

## 2. Prepare the VPS

SSH in and get the code. Use your token as the password when git asks:

```sh
git clone https://github.com/batsiapp/veyra.git
cd veyra
sudo ./deploy/vps/setup-vps.sh
```

The script adds swap, installs Docker, and turns on the firewall with only
SSH allowed in. Log out and back in once so your user can run `docker`.

Log in to GitHub's image registry, using your token as the password:

```sh
docker login ghcr.io -u YOUR-GITHUB-USERNAME
```

## 3. Settings

```sh
cp .env.example .env
chmod 600 .env
nano .env
```

Set (or add, where a line is missing) at least these values:

```dotenv
VEYRA_ENV=production
# any long random string, for example from: openssl rand -hex 16
VEYRA_POSTGRES_PASSWORD=
# the add-on's password, from: openssl rand -hex 24
VEYRA_EA_TOKEN=
VEYRA_EA_URL=http://172.30.0.20/ea/poll
# leave false until you've watched it on a demo account
VEYRA_EA_ALLOW_LIVE=false
VEYRA_TRADING_ENABLED=false
VEYRA_AUTOPILOT_ENABLED=false
```

The stack sets the database address, the broker provider (`ea`) and the
listening addresses itself, so leave those empty in `.env`.

## 4. Start it

```sh
./deploy/vps/veyra.sh pull
./deploy/vps/veyra.sh up -d
./deploy/vps/veyra.sh ps
curl http://127.0.0.1:8080/health
```

`/ready` reports `degraded` with `broker: stale` until MT4 is connected
(steps 6–8). That's expected.

## 5. Open the console and the MT4 screen from your computer

On **your own computer**, open an SSH tunnel and leave it running:

```sh
ssh -N -L 3000:127.0.0.1:3000 -L 6080:127.0.0.1:6080 YOUR-USER@YOUR-VPS-IP
```

Then, in your browser:

- the console: <http://localhost:3000>
- the MT4 screen: <http://localhost:6080/vnc.html>, then press **Connect**

The MT4 screen has no password of its own. It's protected by being reachable
only through your SSH login, so never publish port 6080.

## 6. Install MT4

On the VPS:

```sh
./deploy/vps/veyra.sh exec mt4 install-mt4.sh
```

This uses MetaQuotes' general installer. To use your broker's installer,
add its download link to the end of the command (`... install-mt4.sh https://...`).
The installer opens on the MT4 screen in your browser, so click through it
there. The terminal then starts by itself within a minute and restarts if it
ever closes. Log in to your broker (demo) account in it.

## 7. Allow the add-on in MT4

In MT4 (on the browser screen): **Tools → Options → Expert Advisors**:

- tick **Allow automated trading**;
- tick **Allow WebRequest for listed URL** and add `http://172.30.0.20`.

## 8. Build and attach the add-on

On the VPS:

```sh
./deploy/vps/compile-ea.sh
./deploy/vps/veyra.sh restart mt4
```

The build should end with `EA compiled disarmed`. In MT4, open a chart (for
example EURUSD). Drag **VeyraProbe** from **Navigator → Expert Advisors**
onto it, click OK, and make sure the **AutoTrading** button is green.

Check the connection:

```sh
curl http://127.0.0.1:8080/ready   # "ready" and "broker":"connected"
curl -X POST http://127.0.0.1:8080/commands/account_snapshot
```

The console now shows the account. Veyra can see it but still cannot trade.

## 9. AI model, safety limits, notifications

These are ordinary `.env` settings, explained in
[`GETTING_STARTED.md`](../../GETTING_STARTED.md) section 7 and in
`.env.example`. After editing `.env`, apply the change with:

```sh
./deploy/vps/veyra.sh up -d
```

Set up a notification channel in the console's **Notifications** tab, so the
watchdog can tell you if the service stops.

## 10. Real trading

Follow [`GETTING_STARTED.md`](../../GETTING_STARTED.md) section 9 first:
watch the autopilot with trading off, on a demo account, at 0.01 lots. Real
orders need both switches:

1. Set `VEYRA_EA_ALLOW_LIVE=true` in `.env`, then run
   `./deploy/vps/compile-ea.sh`, then `./deploy/vps/veyra.sh restart mt4`.
2. Turn on **Execution** in the console's **Settings** tab.

**Emergency stop:** the **kill switch** in the console's **Risk** tab, or:

```sh
curl -X POST http://127.0.0.1:8080/risk/policy -H 'Content-Type: application/json' -d '{"killSwitch": true}'
```

`./deploy/vps/veyra.sh stop mt4` also stops trading, because orders only
happen through MT4.

Run only one copy of Veyra per broker account.

## Everyday commands

| Task | Command |
| --- | --- |
| Status | `./deploy/vps/veyra.sh ps` |
| Logs | `./deploy/vps/veyra.sh logs -f veyra` (or `mt4`, `console`) |
| Update to the newest version | `git pull && ./deploy/vps/veyra.sh pull && ./deploy/vps/veyra.sh up -d` |
| Back up the database | `./deploy/vps/veyra.sh exec -T postgres pg_dump -U veyra -Fc veyra > veyra-$(date +%F).dump` |
| Restore a backup into an empty database | `./deploy/vps/veyra.sh exec -T postgres pg_restore -U veyra -d veyra --no-owner < FILE.dump` |
| Memory use | `free -h` and `docker stats --no-stream` |
| Stop everything (data is kept) | `./deploy/vps/veyra.sh down` |

Copy backups off the VPS, for example with `scp` to your computer. Everything
else (MT4, its login and charts, the database) lives in the Docker volumes
`veyra-mt4-wine` and `veyra-postgres-data`, which survive restarts and updates.

## On a 1 GB VPS

All five containers together use roughly 600–800 MB, with MT4 the largest.
The swap file absorbs peaks, but if `free -h` shows swap steadily filling or
the VPS feels slow, move to 2 GB of RAM. The console is only needed while you
look at it: `./deploy/vps/veyra.sh stop console` frees about 100 MB, and
`./deploy/vps/veyra.sh start console` brings it back.

## Known limits

- This Linux/Wine setup is new. The original project was proven with MT4
  under Wine on macOS. GitHub Actions checks that every container starts and
  that the add-on's network path reaches Veyra, but a real broker login on
  this image hasn't been tested yet. Check MT4's **Experts** tab after
  attaching the add-on.
- MT4 updates itself (LiveUpdate) and can come back with the add-on detached
  from its chart. After an update, check the chart and `/ready`.
