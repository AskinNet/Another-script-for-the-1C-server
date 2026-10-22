# AGENTS.md — svc1c

Instructions for an AI agent that installs, configures or tests this script on a Windows host.

## What it is

`svc1c.os` is a OneScript script that maintains infobases on a 1C:Enterprise 8.3 server cluster:
lock/unlock infobases, kill sessions, update configuration from a 1C repository (storage),
apply DB configuration (`/UpdateDBCfg`) and restart the 1C server services.
It talks to the cluster through `rac.exe` → RAS → ragent, and to the infobase through the Designer (v8runner).

```
svc1c.os  --rac.exe-->  RAS (:1545)  -->  ragent (:1540) / rmngr (:1541)  -->  infobases
          --1cv8.exe DESIGNER (v8runner)-->  infobase (UpdateDBCfg, storage update)
```

## Layout

| Path | Purpose |
|---|---|
| `svc1c.os` | the script |
| `packagedef` | pinned OneScript dependencies (installed locally by `opm install -l`) |
| `oscript.cfg` | `lib.additional=oscript_modules` — OneScript 2.x does not look into `oscript_modules` by itself |
| `install.ps1` | installs dependencies, patches irac, runs a syntax check (idempotent) |
| `demo-server.yml` | production-like config example (demo values) |
| `Tests.yml` | config example with repository (storage) settings |
| `hs-task-sql.yml` | config for a local test cluster (one test infobase, no storages) |
| `batch.bat` | entry point for Windows Task Scheduler |
| `etc/` | helper .bat files: register/unregister 1C server and RAS services, stop/restart with temp cleanup |
| `etc/irac-1.4.0-empty-record.patch` | description of the irac fix that `install.ps1` applies |

## Prerequisites

- Windows host with the 1C:Enterprise 8.3 server installed (`C:\Program Files\1cv8\<version>\bin`), ragent running.
- OneScript **2.x** (tested on 2.2.0). Default location `C:\Program Files\OneScript`
  (release zip/installer from https://github.com/EvilBeaver/OneScript/releases; winget only has 1.9.x).
- Internet access for `opm install` (hub.oscript.io).
- RAS service (see below) unless `serverRAS.useDemonRAS: false`.
- Administrator rights only for: creating the RAS service and the `restart` command (`SC STOP/START`, `TASKKILL`).

## Install

```powershell
git clone https://github.com/AskinNet/Another-script-for-the-1C-server.git C:\svc1c
cd C:\svc1c
powershell -ExecutionPolicy Bypass -File install.ps1                      # OneScript in C:\Program Files\OneScript
powershell -ExecutionPolicy Bypass -File install.ps1 -OneScriptHome D:\OneScript   # other location
```

Expected tail: `irac patch: applied` (or `already applied`), `No errors.`, `== done`.
Never commit `oscript_modules/` (it is in `.gitignore`).

## RAS service

The script expects RAS on `serverRAS.serverRAS:serverRAS.portRAS`. Create it once (elevated cmd), using the same
platform version as ragent:

```bat
sc create "1C:Enterprise 8.3 Remote Server" binPath= "\"C:\Program Files\1cv8\8.3.27.2214\bin\ras.exe\" cluster --service --port=1545 localhost:1540" start= auto obj= "NT AUTHORITY\LocalService" DisplayName= "1C:Enterprise 8.3 Remote Server"
sc start "1C:Enterprise 8.3 Remote Server"
```

Check: `"C:\Program Files\1cv8\<version>\bin\rac.exe" localhost:1545 cluster list`.
RAS needs no cluster rights, so `LocalService` is enough. Alternative: `etc\register-ras.bat <version> <port prefix>`
(edit the account in it first). With `useDemonRAS: false` the script starts its own `ras.exe` on `mportRAS` and kills it afterwards.

## Configure

Copy an example (`demo-server.yml`) to `<host>.yml` and fill it in. Real configs with passwords must stay out of git.

| Key | Meaning |
|---|---|
| `batchМode` | comma-separated commands for `batch`. **The `М` is Cyrillic** — copy the key, do not retype it |
| `debug` | `true` → also writes `svc1c_debug.log` |
| `server1c.server`, `port`, `portCluster1C` | cluster host, rmngr port (1541), ragent port (1540) |
| `server1c.version` | exact platform version for the Designer. If it is not installed, v8find silently picks another one |
| `server1c.1cDemonName` | ragent Windows service name (used by `restart`) |
| `server1c.Path1cService` | cluster registry dir (`...\reg_1541`); `restart` deletes `SNCCNTX*`/`STT*` there. Must not be empty |
| `server1c.lockTime` | lock duration, seconds |
| `server1c.restartWaitSec` | optional, default 120: how long `restart` waits for the cluster to answer (retry every 5 s); exit code 1 if it does not |
| `server1c.clusterAdmin`, `clusterAdminPassword` | cluster administrator, empty if none |
| `server1c.bases.<name>.user`, `password` | infobase administrator (required if the infobase has users) |
| `server1c.bases.<name>.allowKey` | permission code to enter a locked infobase |
| `server1c.bases.<name>.1cstorages.<id>` | `path`, `user`, `pass`, `name` (extension name; omit `name` for the main configuration) |
| `serverRAS.serverRAS`, `portRAS` | RAS address |
| `serverRAS.useDemonRAS` | `true` = use RAS service; `false` = start local `ras.exe` on `mportRAS` |
| `serverRAS.pathToBin1c` | `C:\Program Files\1cv8` (version is appended) |
| `serverRAS.1cRasDemonName`, `RestartRas` | RAS service name; restart it together with ragent |

YAML gotcha: write Windows paths in **single quotes** (`'C:\server1C\reg_1541'`). In double quotes oscript-yaml
unescapes twice and `\r`, `\t`, `\n` turn into control characters.

## Run

```bat
cd /d C:\svc1c
"C:\Program Files\OneScript\bin\oscript.exe" svc1c.os <config>.yml <command>
```

Commands: `lock`, `unlock`, `updateFromStorage`, `updateDB`, `restart`, `batch` (runs `batchМode`).
Run from the script folder: the config path, `oscript.cfg` and `svc1c.log` are relative to the current directory.
Exit code 1 on any error; details in `svc1c.log`. For a schedule use `batch.bat` (edit the config name in it).

## Test

1. `oscript -check svc1c.os` → `No errors.`
2. Use a dedicated test infobase only (copy `hs-task-sql.yml`). Fill the infobase admin user/password; never guess passwords.
3. Run `lock`, then verify with `rac infobase info --cluster=<id> --infobase=<id> --infobase-user=... --infobase-pwd=...`
   (`sessions-deny: on`, `scheduled-jobs-deny: on`, `permission-code`), then `unlock`, `updateDB`, `batch`.
4. Do not run `restart` on a shared host without approval: it stops ragent and kills all rphost processes.
   Instead run with `debug: true` and inspect the generated bat text in `svc1c_debug.log`.
5. Leave the test infobase unlocked when done.

## Known issues

- irac 1.4.0 + 1commands 1.5.0 on OneScript 2.x: trailing empty line in rac output → empty record →
  `ИнформационнаяБаза.os:473` fails. Fixed by `install.ps1`; re-run it after every `opm install`/update.
- `rac` prints OEM-encoded text on Windows; the script sets `RAC_ENCODING=OEM` itself.

## Rules for agents

- Work in a branch `agent/<task>-<yyyymmdd>`, open a PR; do not push to `main`.
- Never commit real hosts, users or passwords; examples use `demo`, `demo-server`, `demo-password`.
- Do not touch infobases that are not listed in the test config.
