# Aliyun Server Governance Audit

## Scope

- Audit date: `2026-03-23`
- Hostname: `Iter-1024`
- Access account used: `iterlife-reunion`
- Audit focus: directory layout starting from `/home`, then runtime directories, services, ports, permissions, and governance risks

## Executive Summary

The host is running production traffic successfully, but the machine has grown into a mixed-use server instead of a clearly governed production node.

The current production runtime is centered on `/apps`, Docker, Nginx, and a webhook systemd service. However, `/home` still contains migration leftovers, ad hoc backups, duplicate SSH material, and user-specific operational artifacts. In parallel, the host also contains historical panel software under `/www`, broad application sudo privileges, multiple public-facing services, and production Git working trees with local modifications.

The main governance conclusion is:

1. The system is operable but not yet hardened.
2. The biggest security issue is `iterlife-reunion` having `NOPASSWD: ALL`.
3. The biggest operational issue is production drift caused by live Git repositories and manual changes on the host.
4. The biggest storage issue is Docker image accumulation in `/var/lib/docker`, not `/home`.

## Execution Policy

As of this audit thread, all final server-side execution actions must be confirmed by the owner one by one before execution.

The execution record below distinguishes:

- already executed actions
- inspected but not executed actions
- pending actions that require explicit owner confirmation before the next step

## Execution Record

### Confirmed Environment Facts

1. ECS security group strategy has been confirmed by the owner as minimum-open.
2. Production application traffic is routed through Nginx and localhost-bound containers.
3. Additional host services still exist outside the core app path, including BT panel, MySQL, Redis, and Squid.

### Executed Actions

#### Action E1: Narrow `iterlife-reunion` sudo capability

- Governance reason:
  - The account previously had `NOPASSWD: ALL`, which made the application/operator user equivalent to root.
- Chosen scheme:
  - Replace full passwordless root escalation with a read-only sudo baseline limited to service inspection and socket inspection.
- Executed action:
  - `iterlife-reunion` no longer has `NOPASSWD: ALL`.
  - Current passwordless sudo scope is limited to:
    - `systemctl status *`
    - `systemctl cat *`
    - `systemctl list-units *`
    - `systemctl list-timers *`
    - `journalctl -u * --no-pager`
    - `ss -lntp`
- Current status:
  - Executed
- Residual risk:
  - The account is still in the `wheel` group.
  - This means password-based sudo may still be theoretically possible if a valid password exists.
- Next-step candidate:
  - Remove `iterlife-reunion` from `wheel` after explicit owner confirmation.

#### Action E2: Delete duplicated SSH materials from migration leftovers

- Governance reason:
  - The migration archive retained duplicate SSH private key and authorization material outside the active `~/.ssh` path.
- Chosen scheme:
  - Delete the obsolete `openclaw_ssh` directory under the migration archive and keep only the active SSH directory in `/home/iterlife-reunion/.ssh`.
- Executed action:
  - Deleted the following duplicated files:
    - `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717/extra/openclaw_ssh/authorized_keys`
    - `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717/extra/openclaw_ssh/id_rsa`
    - `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717/extra/openclaw_ssh/id_rsa.pub`
    - `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717/extra/openclaw_ssh/id_rsa.pub.bak.20260225-170449`
    - `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717/extra/openclaw_ssh/known_hosts`
  - Removed the now-empty directory:
    - `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717/extra/openclaw_ssh`
- Verification:
  - The path no longer exists.
- Current status:
  - Executed

### Pending Actions Requiring Explicit Confirmation

#### Action P0-1: Fully remove privileged admin path from `iterlife-reunion`

- Governance reason:
  - The sudoers narrowing is in place, but `wheel` membership remains.
- Proposed scheme:
  - Remove `iterlife-reunion` from supplementary group `wheel`.
  - Keep only `iterlife-reunion` and `docker` groups unless another justified group is required.
- Planned action:
  - Update supplementary groups for the account.
- Execution rule:
  - Must be confirmed immediately before execution.
- Status:
  - Owner confirmed
  - Completed by owner through manual execution
- Manual execution command:
  - `sudo gpasswd -d iterlife-reunion wheel`
- Manual verification commands:
  - `id iterlife-reunion`
  - `groups iterlife-reunion`
- Verification result:
  - `id iterlife-reunion` -> `uid=1003(iterlife-reunion) gid=1003(iterlife-reunion) groups=1003(iterlife-reunion),988(docker)`
  - `groups iterlife-reunion` -> `iterlife-reunion : iterlife-reunion docker`

#### Action P0-2: Reduce host-level Redis exposure

- Governance reason:
  - Redis is listening on `0.0.0.0:6379`.
  - Config currently uses `bind 0.0.0.0` and `protected-mode no`.
- Proposed scheme:
  - Bind Redis only to `127.0.0.1` and `172.17.0.1` so that local host and Docker `host-gateway` access still work.
  - Re-enable `protected-mode yes`.
- Planned action:
  - Backup `/etc/redis.conf`
  - Change:
    - `bind 0.0.0.0` -> `bind 127.0.0.1 172.17.0.1`
    - `protected-mode no` -> `protected-mode yes`
  - Restart `redis.service`
  - Verify listener and application health
- Execution rule:
  - Must be confirmed immediately before execution.
- Status:
  - Owner confirmed
  - Completed by owner through manual execution
  - Owner requested that the temporary backup file be deleted after successful execution and verification
- Manual execution plan:
  - Create a temporary backup of `/etc/redis.conf`
  - Update bind and protected-mode settings
  - Restart `redis.service`
  - Verify listener contraction and service health
  - Delete the temporary backup file after successful verification
- Verification result:
  - `redis.service` is active after restart
  - `6379` now listens on `127.0.0.1:6379` and `172.17.0.1:6379`
  - `/etc/redis.conf` now contains:
    - `bind 127.0.0.1 172.17.0.1`
    - `protected-mode yes`
- Final cleanup status:
  - Temporary backup file deleted by owner after successful verification

#### Action P0-3: Reduce host-level MySQL exposure without breaking containers

- Governance reason:
  - MySQL is listening on `*:3306` and `*:33060`.
  - Application containers use `DB_HOST=host.docker.internal`, which maps to Docker host-gateway access.
- Proposed scheme:
  - Keep `3306` reachable from localhost and Docker host-gateway only.
  - Restrict `33060` to localhost only because no active usage has been observed.
- Planned action:
  - Backup `/etc/my.cnf`
  - Add under `[mysqld]`:
    - `bind-address=127.0.0.1,172.17.0.1`
    - `mysqlx-bind-address=127.0.0.1`
  - Restart `mysqld.service`
  - Verify:
    - `3306` listener is no longer public
    - `33060` is localhost only
    - application health endpoints remain healthy
- Execution rule:
  - Must be confirmed immediately before execution.
- Status:
  - Owner reviewed
  - Deferred by owner
  - Not executed at this stage

#### Action P0-4: Reduce host-level Squid exposure

- Governance reason:
  - Squid is listening on `*:3128`.
  - No current business dependency has been identified in application configs or short-window connection checks.
- Proposed scheme:
  - Bind Squid to localhost only first, while keeping the service enabled.
- Planned action:
  - Backup `/etc/squid/squid.conf`
  - Change:
    - `http_port 3128` -> `http_port 127.0.0.1:3128`
  - Validate config
  - Restart `squid.service`
  - Recheck listeners
- Execution rule:
  - Must be confirmed immediately before execution.
- Status:
  - Owner confirmed
  - Completed by owner through manual execution
- Manual execution plan:
  - Create a temporary backup of `/etc/squid/squid.conf`
  - Update listener from public bind to localhost-only bind
  - Validate config
  - Restart `squid.service`
  - Verify listener contraction and service health
  - Delete the temporary backup file after successful verification
- Verification result:
  - `squid.service` is active after restart
  - `3128` now listens on `127.0.0.1:3128`
  - `/etc/squid/squid.conf` now contains:
    - `http_port 127.0.0.1:3128`
- Final cleanup status:
  - Temporary backup file deleted by owner after successful verification

#### Action P0-5: Decide BT panel exposure strategy

- Governance reason:
  - BT panel is still running and listening on `0.0.0.0:8888`.
  - Its startup path is not managed by a simple `bind.pl` setting alone; it also relies on `/etc/rc.d/init.d/bt`, `BT-Panel`, `BT-Task`, and related runtime code.
- Proposed scheme:
  - Do not modify BT panel binding until the owner chooses the intended access model.
  - Options to choose later:
    - keep current behavior under security-group-only protection
    - refactor BT panel to localhost-only access with SSH tunnel workflow
    - retire BT panel after migration to documented operations paths
- Planned action:
  - None until the owner confirms the target model
- Execution rule:
  - Must be confirmed immediately before execution.
- Status:
  - Owner determined BT panel is unwanted software with no valid operational value
  - Cleanup planning in progress
  - Final removal actions still require explicit per-item confirmation before execution

## BT Cleanup Findings

The host currently contains an active BT software stack rather than a passive leftover.

### Active BT Runtime

- `BT-Panel` process is running as root
- `BT-Task` process is running as root
- `BT-FirewallServices.service` is enabled and running as root
- port `8888` is still publicly listening

### BT Startup Hooks

Observed startup and command-entry artifacts:

- `/etc/rc.d/init.d/bt`
- `/etc/rc.d/rc0.d/K25bt`
- `/etc/rc.d/rc1.d/K25bt`
- `/etc/rc.d/rc2.d/S55bt`
- `/etc/rc.d/rc3.d/S55bt`
- `/etc/rc.d/rc4.d/S55bt`
- `/etc/rc.d/rc5.d/S55bt`
- `/etc/rc.d/rc6.d/K25bt`
- `/etc/systemd/system/BT-FirewallServices.service`
- `/etc/systemd/system/multi-user.target.wants/BT-FirewallServices.service`
- `/usr/bin/bt` -> `/etc/rc.d/init.d/bt`

### BT File Roots

Observed BT file roots:

- `/www/server/panel`
- `/www/server/bt_tomcat_web`

### BT-Related Command Shims

The BT init script manages or recreates command-entry helpers such as:

- `/usr/bin/bt`
- `/usr/bin/btpip`
- `/usr/bin/btpython`

### BT Coupling Notes

1. BT is not part of the current documented Nginx reverse-proxy path for IterLife services.
2. The legacy `/etc/rc.d/init.d/nginx` script still contains BT-related WAF handling logic tied to:
   - `/www/server/panel/vhost/nginx/btwaf.conf`
   - `/www/server/panel/vhost/nginx/free_waf.conf`
3. Current active Nginx service is managed by systemd using `/usr/sbin/nginx`, not by `/etc/init.d/nginx`.
4. This means BT removal should still review legacy init-script coupling, but the live HTTP path is not primarily dependent on BT.

## Proposed BT Cleanup Action Packets

The cleanup should be executed in small confirmed packets instead of one destructive sweep.

### BT-1 Stop Active BT Runtime

- Governance reason:
  - Active BT processes and port `8888` keep the unwanted management surface alive.
- Proposed scheme:
  - Stop BT processes first without deleting files yet.
- Planned action:
  - Stop `BT-FirewallServices.service`
  - Stop BT panel runtime through `/etc/rc.d/init.d/bt stop`
  - Verify `8888` is no longer listening
  - Verify no `BT-Panel`, `BT-Task`, or `BT-FirewallServices` processes remain
- Status:
  - Owner confirmed
  - Completed by owner through manual execution
- Verification result:
  - `BT-FirewallServices.service` is inactive after stop
  - port `8888` is no longer listening
  - `BT-Panel` and `BT-Task` were stopped through `/etc/rc.d/init.d/bt stop`
  - No remaining active BT runtime was observed, aside from the shell-side grep command used during verification

### BT-2 Disable All BT Startup Hooks

- Governance reason:
  - Even if BT is stopped, it can return after reboot because multiple startup hooks remain.
- Proposed scheme:
  - Disable systemd and SysV startup paths before deleting files.
- Planned action:
  - Disable `BT-FirewallServices.service`
  - Remove or unregister BT init-script startup symlinks under `rc*.d`
  - Remove `/usr/bin/bt` command entry
  - Remove any `btpython` and `btpip` shims if present
- Status:
  - Owner confirmed
  - Completed by owner through manual execution
- Verification result:
  - `BT-FirewallServices.service` is now `disabled`
  - BT startup symlinks under `rc*.d` were removed
  - `/usr/bin/bt`, `/usr/bin/btpip`, and `/usr/bin/btpython` were removed

### BT-3 Remove BT File Trees

- Governance reason:
  - The software payload remains under `/www/server/panel` and related BT directories.
- Proposed scheme:
  - Delete BT file roots only after runtime and startup hooks are already disabled.
- Planned action:
  - Remove `/www/server/panel`
  - Remove `/www/server/bt_tomcat_web` if it is confirmed to be BT-only and unused
- Status:
  - Owner confirmed
  - Completed by owner through manual execution
- Verification result:
  - `/www/server/panel` was removed
  - `/www/server/bt_tomcat_web` was removed
  - No remaining BT file roots were found under `/www/server`
  - Remaining BT-specific cleanup targets are now reduced to:
    - `/etc/systemd/system/BT-FirewallServices.service`
    - `/etc/rc.d/init.d/bt`
  - Observed `/usr/lib/firmware/rtl_bt` is unrelated Bluetooth firmware and not part of BT panel software

### BT-4 Remove BT Service Definitions and Final Leftovers

- Governance reason:
  - Service definitions and helper artifacts can leave false startup references and noise.
- Proposed scheme:
  - Remove the remaining BT service definitions and verify no path references remain.
- Planned action:
  - Remove `/etc/systemd/system/BT-FirewallServices.service`
  - Remove dangling symlink `/etc/systemd/system/multi-user.target.wants/BT-FirewallServices.service`
  - Verify no remaining `/www/server/panel` or `/etc/rc.d/*bt` references remain in live startup paths
- Status:
  - Owner confirmed
  - Completed by owner through manual execution
- Verification result:
  - `/etc/systemd/system/BT-FirewallServices.service` was removed
  - `/etc/systemd/system/multi-user.target.wants/BT-FirewallServices.service` was removed
  - `/etc/rc.d/init.d/bt` was removed
  - `systemctl daemon-reload` was executed
  - `systemctl list-unit-files` no longer shows `BT-FirewallServices`
  - Remaining path `/usr/lib/firmware/rtl_bt` is unrelated Bluetooth firmware and not part of BT panel software

## BT Cleanup Conclusion

The BT panel software stack has been removed from the server in four completed packets:

1. runtime stopped
2. startup hooks disabled
3. BT file trees deleted
4. system-level service and init entrypoints removed

Based on the final verification collected in this thread, the server no longer retains active BT panel runtime, startup entrypoints, or BT software directories.

## Structure Governance Findings

After BT cleanup, the main structure-governance targets are now concentrated in `/home/iterlife-reunion` plus a few archival helper directories under `/apps`.

### Current Classification

#### Runtime Assets To Keep

These are active runtime or runtime-adjacent paths and should not be treated as cleanup targets by default:

- `/apps/config`
- `/apps/data`
- `/apps/logs`
- `/apps/static`
- `/apps/iterlife-reunion`
- `/apps/iterlife-reunion-ui`
- `/apps/iterlife-expenses`
- `/apps/iterlife-expenses-ui`
- `/apps/iterlife-reunion-stack`
- `/home/iterlife-reunion/.ssh`
- `/home/iterlife-reunion/.docker`

#### Empty or Shadow Paths

These do not currently provide meaningful runtime value:

- `/home/iterlife-reunion/apps`

Observed status:

- present but effectively empty
- can mislead operators into thinking `/home/iterlife-reunion/apps` is the real runtime root, while the actual runtime root is `/apps`

#### Historical Backup and Archive Candidates

These look like historical copies rather than active runtime assets:

- `/home/iterlife-reunion/backup`
- `/home/iterlife-reunion/backups`
- `/apps/backups`
- `/apps/deploy-logs`

#### High-Noise Migration Residue

The largest remaining non-runtime archive is:

- `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717` about `1.4G`

Its main components include:

- `requested/backups` about `1.2G`
- `extra/node-v18.19.0-linux-x64` about `184M`
- `extra/.nvm` about `3.1M`

### Size Profile

Current major structure-governance candidates:

- `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717`: about `1.4G`
- `/home/iterlife-reunion/backup`: about `493M`
- `/home/iterlife-reunion/backups`: about `2.6M`
- `/apps/backups`: about `76K`
- `/apps/deploy-logs`: about `16K`
- `/home/iterlife-reunion/apps`: about `4K`

This confirms that the largest cleanup opportunity is still the old migration payload, followed by the legacy `backup` tree.

## Proposed Structure Governance Action Packets

The directory cleanup should be executed in small confirmed packets rather than as one destructive sweep.

### ST-1 Remove Empty Shadow Path

- Governance reason:
  - `/home/iterlife-reunion/apps` is empty and misleading because the real runtime root is `/apps`.
- Proposed scheme:
  - Remove the empty shadow directory to eliminate path ambiguity.
- Planned action:
  - Delete `/home/iterlife-reunion/apps`
- Status:
  - Owner confirmed
  - Executed
- Verification result:
  - `/home/iterlife-reunion/apps` was removed

### ST-2 Remove Tiny Redundant Archive Set Under `/apps`

- Governance reason:
  - `/apps/backups` and `/apps/deploy-logs` are small and appear to be historical helper snapshots rather than active runtime requirements.
- Proposed scheme:
  - Remove the contents after one final visual confirmation, because they are low-risk and easily reconstructible if needed.
- Planned action:
  - Delete:
    - `/apps/backups`
    - `/apps/deploy-logs`
- Status:
  - Owner confirmed
  - Executed
- Verification result:
  - `/apps/backups` was removed
  - `/apps/deploy-logs` was removed

### ST-3 Remove Snapshot-Style Code Backups Under `/home/iterlife-reunion/backups`

- Governance reason:
  - `/home/iterlife-reunion/backups` contains lightweight code snapshots of IterLife repositories, which duplicate Git-managed source already present under `/apps` and GitHub.
- Proposed scheme:
  - Remove these local code snapshots after explicit confirmation.
- Planned action:
  - Delete `/home/iterlife-reunion/backups`
- Status:
  - Owner confirmed
  - Executed
- Verification result:
  - `/home/iterlife-reunion/backups` was removed

### ST-4 Remove Legacy Manual Backup Tree Under `/home/iterlife-reunion/backup`

- Governance reason:
  - `/home/iterlife-reunion/backup` contains ad hoc backup content including:
    - `docker-images`
    - `code-sync-*`
    - `compose`
    - `nginx`
  - This tree is large, manually assembled, and inconsistent with the intended runtime layout.
- Proposed scheme:
  - Remove the legacy manual backup tree after explicit confirmation.
- Planned action:
  - Delete `/home/iterlife-reunion/backup`
- Status:
  - Owner confirmed
  - Executed
- Verification result:
  - `/home/iterlife-reunion/backup` was removed

### ST-5 Remove Migration Residue Tree

- Governance reason:
  - `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717` is a one-time migration residue and currently the single largest non-runtime directory in `/home`.
- Proposed scheme:
  - Remove the entire migration tree after explicit confirmation, now that SSH key duplicates and BT-related confusion have already been addressed.
- Planned action:
  - Delete `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717`
- Status:
  - Owner confirmed
  - Executed
- Verification result:
  - `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717` was removed

### ST-6 Normalize Backup Strategy Going Forward

- Governance reason:
  - The server previously used multiple overlapping roots:
    - `backup`
    - `backups`
    - `/apps/backups`
  - This causes ambiguity in ownership and retention.
- Proposed scheme:
  - After cleanup, reserve one canonical archive root only if local archives are still required.
  - Recommended canonical local path:
    - `/apps/backups`
  - If local archives are not needed, prefer remote backup mechanisms and keep no ad hoc local copy trees.
- Planned action:
  - Governance-only decision at this stage
- Status:
  - Decided
  - Executed as governance baseline
- Final governance baseline:
  - Do not recreate ad hoc local backup roots under `/home/iterlife-reunion`, including names such as `backup`, `backups`, or similar one-off archive trees.
  - If local temporary archives are ever required again, use one canonical path only:
    - `/apps/backups`
  - Prefer remote or off-host backup mechanisms over long-term local archive retention.
  - Any new local backup retention rule should be documented together with owner, purpose, retention window, and cleanup trigger.

## Post-Governance Snapshot

### `/home/iterlife-reunion` After Cleanup

The home directory is now reduced to a minimal login footprint only:

- `.ssh`
- `.docker`
- `.bash_history`
- `.bash_logout`
- `.bash_profile`
- `.bashrc`
- `.gitconfig`

There are no remaining migration trees, local backup trees, duplicated SSH material, or shadow application directories under `/home/iterlife-reunion`.

### `/apps` Runtime Layout After Cleanup

The runtime root remains `/apps`, and its current top-level layout is:

- `/apps/config`
- `/apps/data`
- `/apps/logs`
- `/apps/static`
- `/apps/iterlife-reunion`
- `/apps/iterlife-reunion-ui`
- `/apps/iterlife-reunion-stack`
- `/apps/iterlife-expenses`
- `/apps/iterlife-expenses-ui`

The former auxiliary directories `/apps/backups` and `/apps/deploy-logs` have been removed.

### Account Retention Decision

The owner explicitly chose not to remove the `iterlife-reunion` account.

This remains the correct operational decision at the current stage because:

- `iterlife-app-deploy-webhook.service` still runs as `iterlife-reunion`
- `/apps` runtime assets are still owned by `iterlife-reunion:iterlife-reunion`
- the account still acts as the deployment and service-ownership principal for the current application stack

### Current Listener Snapshot After Governance Actions

Successfully reduced or removed exposure:

- Redis now listens on `127.0.0.1:6379` and `172.17.0.1:6379`
- Squid now listens on `127.0.0.1:3128`
- BT panel listener on `0.0.0.0:8888` has been removed together with the BT software stack

Still intentionally retained or pending further decision:

- `0.0.0.0:80` and `0.0.0.0:443` for Nginx
- `0.0.0.0:22` for SSH
- `*:3306` and `*:33060` for MySQL, pending separate owner confirmation if further contraction is desired

## Next Priority Queue Excluding P0-3

With MySQL exposure contraction explicitly deferred, the highest remaining governance priorities are now:

1. Production drift elimination on live Git working trees under `/apps`
2. Review and possible retirement of non-core host services still listening or running outside the main app path
3. Permission-baseline tightening across `/apps`

### Production Drift Snapshot

Current dirty production repositories still observed:

1. `/apps/iterlife-reunion`
   - modified: `deploy-reunion-from-ghcr.sh`
   - modified: `deploy-reunion-ui-from-ghcr.sh`
2. `/apps/iterlife-expenses-ui`
   - modified: `deploy/compose/expenses-ui.yml`

Current clean production repositories observed:

1. `/apps/iterlife-reunion-ui`
2. `/apps/iterlife-reunion-stack`
3. `/apps/iterlife-expenses`

Governance meaning:

- the production host is still not deploy-only
- release behavior may now depend on host-local modifications instead of GitHub state alone
- further cleanup should not proceed as if the host were a clean deployment target

Observed change intent by file:

1. `/apps/iterlife-reunion/deploy-reunion-from-ghcr.sh`
   - local change adds retry logic for GHCR login and image pull
   - this looks like an operational hardening change in deployment behavior, not application-code drift
2. `/apps/iterlife-reunion/deploy-reunion-ui-from-ghcr.sh`
   - local change adds retry logic for GHCR login and image pull
   - this also looks like an operational hardening change in deployment behavior
3. `/apps/iterlife-expenses-ui/deploy/compose/expenses-ui.yml`
   - local change rewrites Compose project name from `iterlife-expenses` to `deploy`
   - this changes runtime naming behavior and is drift-sensitive because it can affect container/network/resource names

### Additional Host Services Still Requiring Review

The following non-core host services remain active after the completed cleanup work:

1. `rpcbind.service`
2. `postfix.service`
3. `mysqld.service`
4. `redis.service`
5. `squid.service`
6. `iterlife-app-deploy-webhook.service`

At this stage:

- `iterlife-app-deploy-webhook.service`, `redis.service`, and `squid.service` remain justified by current architecture
- `mysqld.service` remains separately governed under deferred item `P0-3`
- `rpcbind.service` and `postfix.service` now become the main remaining host-service review targets outside the app stack

Observed review detail:

1. `rpcbind.service`
   - active and listening on `0.0.0.0:111` and `[::]:111`
   - reverse dependency inspection shows no active business service depending on it
   - `rpcinfo -p` shows only `portmapper` itself and no extra registered RPC programs
   - `nfs-utils` package is installed, but `nfs-server.service`, `nfs-mountd.service`, and related NFS services are inactive
2. `postfix.service`
   - active but only listening on `127.0.0.1:25` and `[::1]:25`
   - current `postconf -n` shows `inet_interfaces = localhost`
   - this is lower priority than `rpcbind` because it is not publicly exposed at the socket level

### Proposed Next Governance Packet

#### Action P1-1: Freeze Current Production Drift Into Explicitly Reviewed State

- Governance reason:
  - Dirty working trees already exist on the production host.
  - Until they are explicitly inventoried and reviewed, later cleanup work risks either normalizing hidden hotfixes or accidentally deleting active deployment behavior.
- Proposed scheme:
  - Export and review the exact local diffs from the dirty repos first.
  - Treat this as a freeze-and-document step, not a cleanup step.
  - Do not modify those files yet.
- Planned action:
  - Capture `git diff --stat` and `git diff` for:
    - `/apps/iterlife-reunion`
    - `/apps/iterlife-expenses-ui`
  - Map each modified file to its runtime or deployment purpose
  - Record whether each change appears intentional, emergency, or drift-like
- Execution rule:
  - Read-only inspection is allowed
  - Any later revert, commit, or deployment-model change still requires explicit owner confirmation
- Status:
  - Owner confirmed
  - Read-only inspection completed
- Inspection result:
  - `/apps/iterlife-reunion` at `96b0bed`
    - branch: `main`
    - upstream: `origin/main`
    - remote: `git@github.com:LuJie0403/iterlife-reunion.git`
    - modified: `deploy-reunion-from-ghcr.sh`
    - modified: `deploy-reunion-ui-from-ghcr.sh`
  - `/apps/iterlife-expenses-ui` at `7eb15ab`
    - remote: `git@github.com:LuJie0403/iterlife-expenses-ui.git`
    - modified: `deploy/compose/expenses-ui.yml`
- Drift classification:
  - `deploy-reunion-from-ghcr.sh`
    - local drift type: deployment hardening
    - concrete change: adds configurable retry logic around `docker login` and `docker pull`
    - governance interpretation: likely intentional operational resilience patch
  - `deploy-reunion-ui-from-ghcr.sh`
    - local drift type: deployment hardening
    - concrete change: adds configurable retry logic around `docker login` and `docker pull`
    - governance interpretation: likely intentional operational resilience patch
  - `deploy/compose/expenses-ui.yml`
    - local drift type: runtime naming change
    - concrete change: rewrites Compose project name from `iterlife-expenses` to `deploy`
    - governance interpretation: higher-risk drift because Compose project naming affects runtime resource names and cross-project isolation semantics
- Governance conclusion:
  - The current production drift is limited to deployment-facing files, not application source files.
  - Even so, the host is still acting as a source of truth for deployment behavior, which violates the target deploy-only model.
  - The next correct step is not immediate revert. The next correct step is owner decision on whether to upstream these changes into GitHub or intentionally discard them.
  - For the two `iterlife-reunion` deploy scripts, the current recommendation is to preserve their logic by upstreaming them, not by leaving them only on the host.
    - reason: the retry wrappers around `docker login` and `docker pull` materially improve deployment resilience against transient GHCR/network failures
    - risk if discarded: deployments become more brittle again under temporary registry or network instability
    - preferred governance outcome: merge the retry logic into the GitHub repository on `main`, then return the production worktree to a clean state

#### Action P1-2: Review `rpcbind` and `postfix` Service Necessity

- Governance reason:
  - Both services remain active on the host but are not part of the documented application path.
  - `rpcbind` is still listening on port `111`, and `postfix` is still active on local SMTP.
- Proposed scheme:
  - First confirm whether either service has a real operational dependency.
  - Only after dependency review should disablement or listener contraction be considered.
- Planned action:
  - Inspect unit purpose, listening sockets, package ownership, and current dependency graph
  - If no justified dependency is found, prepare per-service disablement packets for owner confirmation
- Execution rule:
  - Inspection only at this stage
  - Any stop, disable, or uninstall action requires explicit owner confirmation

#### Action P1-3: Retire Public `rpcbind` Exposure If No NFS/RPC Dependency Is Intended

- Governance reason:
  - `rpcbind` is still publicly listening on port `111` over IPv4 and IPv6.
  - No active NFS or RPC service dependency has been observed on the host.
  - This leaves an unnecessary legacy infrastructure surface on the machine.
- Proposed scheme:
  - Stop and disable `rpcbind.service` and `rpcbind.socket`.
  - Verify port `111` is no longer listening.
  - Do not uninstall packages at this stage.
- Planned action:
  - `systemctl stop rpcbind.socket rpcbind.service`
  - `systemctl disable rpcbind.socket rpcbind.service`
  - verify `ss`/`rpcinfo` no longer expose port `111`
- Execution rule:
  - Must be confirmed immediately before execution
- Status:
  - Owner confirmed
  - Completed by owner through manual execution
- Manual execution commands:
  - `sudo systemctl stop rpcbind.socket rpcbind.service`
  - `sudo systemctl disable rpcbind.socket rpcbind.service`
- Verification result:
  - `rpcbind.socket` is disabled and inactive
  - port `111` is no longer listening
  - `rpcinfo -p` no longer returns active `portmapper` registrations

#### Action P1-5A: Upstream `iterlife-reunion` Deploy Hardening Through Dedicated Branch

- Governance reason:
  - The production host contains two deployment-hardening changes that appear valuable and should not remain host-only.
  - These changes improve resilience around transient GHCR login and image-pull failures.
- Proposed scheme:
  - Create a dedicated branch from the current production checkout.
  - Commit only the two deploy-script changes.
  - Push that branch to the remote repository for later review and merge.
- Planned action:
  - create branch from `/apps/iterlife-reunion` `main`
  - commit:
    - `deploy-reunion-from-ghcr.sh`
    - `deploy-reunion-ui-from-ghcr.sh`
  - push the branch to `origin`
- Execution rule:
  - Owner confirmed branch-based upstream path
- Status:
  - Executed
- Execution result:
  - local branch created:
    - `codex/reunion-ghcr-retry-hardening-20260323`
  - commit created:
    - `337025f fix(deploy): retry ghcr login and pull`
  - remote branch pushed:
    - `origin/codex/reunion-ghcr-retry-hardening-20260323`
  - GitHub compare / PR entry:
    - `https://github.com/LuJie0403/iterlife-reunion/pull/new/codex/reunion-ghcr-retry-hardening-20260323`

#### Action P1-5B: Decide Whether To Preserve Or Revert `iterlife-expenses-ui` Compose Project Name Drift

- Governance reason:
  - The current worktree drift changes `deploy/compose/expenses-ui.yml` from `name: iterlife-expenses` to `name: deploy`.
  - This affects Docker Compose project naming behavior.
- Inspection result:
  - repository: `git@github.com:LuJie0403/iterlife-expenses-ui.git`
  - branch: `main`
  - current host commit: `7eb15ab`
  - tracked file in `HEAD`: `name: iterlife-expenses`
  - current worktree file: `name: deploy`
  - current running UI container label:
    - `com.docker.compose.project=deploy`
  - current running API container label:
    - `com.docker.compose.project=deploy`
  - `/apps/iterlife-expenses/deploy/compose/expenses-api.yml` currently also uses:
    - `name: deploy`
- Governance interpretation:
  - The live host is already operating with Compose project name `deploy` for both expenses API and expenses UI.
  - Reverting the UI file to `iterlife-expenses` would make the repository match `HEAD`, but would also reintroduce naming divergence between the UI worktree and the live API project naming convention currently in use.
  - This makes the current UI drift look more like a host-local alignment fix than an accidental typo.
- Recommended decision:
  - Preserve the `name: deploy` behavior, but upstream it properly into the `iterlife-expenses-ui` repository instead of leaving it as host-only drift.
  - Do not revert blindly on the production host.
- Next-step candidate:
  - Create a dedicated branch in `/apps/iterlife-expenses-ui`, commit the `name: deploy` change, and push it for review after explicit owner confirmation.

#### Action P1-6: Normalize `iterlife-expenses` Compose Naming To Match `iterlife-reunion` Governance Pattern

- Governance reason:
  - `iterlife-reunion` and `iterlife-reunion-ui` already follow a clean naming rule:
    - both Compose files use the same business-stack project name `iterlife-reunion`
    - runtime container labels also show `com.docker.compose.project=iterlife-reunion`
  - `iterlife-expenses` and `iterlife-expenses-ui` currently share `com.docker.compose.project=deploy`, which is internally consistent but not business-semantic.
  - For long-term governance, the Compose project name should identify the business stack, not a generic deployment action.
- Standard target:
  - `iterlife-expenses`
- Standardization rule:
  - `iterlife-expenses` API and UI should both use:
    - `name: iterlife-expenses`
  - Their deployment entrypoints should honor the same Compose project name explicitly, rather than relying on a generic `deploy` namespace.
- Files requiring normalization:
  - `/apps/iterlife-expenses/deploy/compose/expenses-api.yml`
  - `/apps/iterlife-expenses-ui/deploy/compose/expenses-ui.yml`
  - optionally, deployment scripts:
    - `/apps/iterlife-expenses/deploy-expenses-api-from-ghcr.sh`
    - `/apps/iterlife-expenses/deploy-expenses-ui-from-ghcr.sh`
- Governance caution:
  - This is not a read-only repository cleanup.
  - Changing Compose project name affects runtime grouping semantics and should be treated as a coordinated deployment change, not just a text edit.
- Recommended sequence:
  1. first upstream branch-only repository normalization
  2. then, in a separate confirmed maintenance step, roll the running expenses API and UI containers onto the standardized project name

#### Action P1-6A: Standardize `iterlife-expenses` API Repository Compose Project Name

- Governance reason:
  - The API-side Compose file is still using the generic project name `deploy`.
  - This should be normalized to the business-stack name `iterlife-expenses`.
- Proposed scheme:
  - Create a dedicated branch from `/apps/iterlife-expenses` `main`
  - Change only:
    - `/apps/iterlife-expenses/deploy/compose/expenses-api.yml`
      - `name: deploy` -> `name: iterlife-expenses`
  - Commit and push the branch for later review
- Execution rule:
  - Owner confirmed
  - Branch-only repository normalization
  - No runtime container change in this step
- Status:
  - Executed
- Execution result:
  - local branch created:
    - `codex/expenses-compose-projectname-20260323`
  - file changed:
    - `/apps/iterlife-expenses/deploy/compose/expenses-api.yml`
      - `name: deploy` -> `name: iterlife-expenses`
  - commit created:
    - `45ab759 fix(deploy): standardize expenses compose project name`
  - remote branch pushed:
    - `origin/codex/expenses-compose-projectname-20260323`
  - GitHub compare / PR entry:
    - `https://github.com/LuJie0403/iterlife-expenses/pull/new/codex/expenses-compose-projectname-20260323`
- Execution note:
  - commit initially failed because the repository had no configured author identity for the `iterlife-reunion` account
  - resolved by setting repository-local Git identity to match recent existing commits in this repository:
    - `user.name=Iter_1024`
    - `user.email=lujie0403@163.com`

#### Action P1-6B: Standardize `iterlife-expenses-ui` Repository Compose Project Name

- Governance reason:
  - The UI-side Compose file also still uses the generic project name `deploy`.
  - To match the `iterlife-reunion` governance pattern, it should share the same business-stack project name as the expenses API side.
- Proposed scheme:
  - Create a dedicated branch from `/apps/iterlife-expenses-ui` `main`
  - Change only:
    - `/apps/iterlife-expenses-ui/deploy/compose/expenses-ui.yml`
      - `name: deploy` -> `name: iterlife-expenses`
  - Commit and push the branch for later review
- Execution rule:
  - Owner confirmed
  - Branch-only repository normalization
  - No runtime container change in this step
- Status:
  - Executed
- Execution result:
  - local branch created:
    - `codex/expenses-ui-compose-projectname-20260323`
  - file committed:
    - `/apps/iterlife-expenses-ui/deploy/compose/expenses-ui.yml`
      - `name: deploy` -> `name: iterlife-expenses`
  - commit created:
    - `d8d5d14 fix(deploy): standardize expenses ui compose project name`
  - remote branch pushed:
    - `origin/codex/expenses-ui-compose-projectname-20260323`
  - GitHub compare / PR entry:
    - `https://github.com/LuJie0403/iterlife-expenses-ui/pull/new/codex/expenses-ui-compose-projectname-20260323`
- Execution note:
  - repository-local Git identity was set to match recent existing commits in this repository:
    - `user.name=Iter_1024`
    - `user.email=lujie0403@gmail.com`

#### Action P1-6C: Roll Running `iterlife-expenses` API/UI From `deploy` Compose Project To `iterlife-expenses`

- Governance reason:
  - Repository normalization has been completed, but the live API and UI containers still run under:
    - `com.docker.compose.project=deploy`
    - network: `deploy_default`
  - This means the runtime naming still does not match the repository governance target.
- Current runtime facts:
  - `iterlife-expenses-api` is healthy on `127.0.0.1:18180`
  - `iterlife-expenses-ui` is serving on `127.0.0.1:13180`
  - both containers currently attach to `deploy_default`
  - current production worktrees are on branch-based normalization branches:
    - `/apps/iterlife-expenses` -> `codex/expenses-compose-projectname-20260323`
    - `/apps/iterlife-expenses-ui` -> `codex/expenses-ui-compose-projectname-20260323`
- Proposed scheme:
  - Treat this as a coordinated maintenance action.
  - Stop and remove the current `deploy`-project containers for expenses API and UI.
  - Recreate them from the standardized Compose files so they re-register under:
    - `com.docker.compose.project=iterlife-expenses`
    - network: `iterlife-expenses_default`
  - Verify health and then optionally remove stale `deploy_default` if no containers remain attached.
- Planned action:
  - pre-check current health and container state
  - stop/remove current expenses API and UI containers
  - recreate API from `/apps/iterlife-expenses/deploy/compose/expenses-api.yml`
  - recreate UI from `/apps/iterlife-expenses-ui/deploy/compose/expenses-ui.yml`
  - verify:
    - API health endpoint
    - UI HTTP response
    - Compose labels now show `iterlife-expenses`
    - containers attach to `iterlife-expenses_default`
  - if `deploy_default` becomes unused, remove that stale network
- Rollback path:
  - if startup fails, recreate the same services again using the previous `deploy` project naming from the pre-change state
  - because image references and container names remain the same, rollback is operationally straightforward but still requires a maintenance decision
- Execution rule:
  - Must be confirmed immediately before execution
- Status:
  - Owner confirmed
  - Completed after focused UI remediation
- Execution result:
  - `iterlife-expenses-api` was recreated successfully
    - health check remained healthy
    - `com.docker.compose.project=iterlife-expenses`
    - network moved to `iterlife-expenses_default`
  - `iterlife-expenses-ui` required one additional focused recreation with explicit `--project-name iterlife-expenses`
  - final UI result:
    - HTTP probe returned `200 OK`
    - `com.docker.compose.project=iterlife-expenses`
    - network moved to `iterlife-expenses_default`
- Final verification:
  - API health endpoint returns `status=ok`
  - UI HTTP endpoint returns `200 OK`
  - both runtime containers now use `com.docker.compose.project=iterlife-expenses`
  - `deploy_default` is now empty and no longer has attached containers
- Next-step candidate:
  - Remove stale Docker network `deploy_default` after explicit owner confirmation

#### Action P1-6D: Return Production Repositories To Stable Tracking Branches After Upstream Handling

- Governance reason:
  - `/apps/iterlife-expenses`, `/apps/iterlife-expenses-ui`, and `/apps/iterlife-reunion` are now sitting on temporary `codex/*` branches created during governance recovery.
  - This is acceptable short-term for capture and push, but not ideal as the long-term production branch posture.
- Proposed scheme:
  - After the relevant remote branches are reviewed and merged, switch each production repository back to its stable tracking branch and ensure worktrees are clean.
- Execution rule:
  - Deferred until remote branch handling is complete
- Current inspection status:
  - Not yet executable
  - Production repositories are still on temporary governance branches:
    - `/apps/iterlife-reunion` -> `codex/reunion-ghcr-retry-hardening-20260323`
    - `/apps/iterlife-expenses` -> `codex/expenses-compose-projectname-20260323`
    - `/apps/iterlife-expenses-ui` -> `codex/expenses-ui-compose-projectname-20260323`
  - Read-only comparison against `origin/main` shows these branch heads are not yet contained in the current remote `main` branches.
- Governance conclusion:
  - Do not switch production repositories back to `main` yet.
  - The correct next step is remote review/merge of the pushed branches.
- Ready-to-run follow-up after remote merge:
  - fetch origin
  - switch each repo back to `main`
  - fast-forward to `origin/main`
  - verify clean worktree

#### Action P1-6E: Remove Stale Docker Network `deploy_default`

- Governance reason:
  - After runtime cutover, `deploy_default` no longer had attached containers.
  - Keeping it would leave misleading runtime residue from the old naming scheme.
- Execution rule:
  - Must be confirmed immediately before execution
- Status:
  - Owner confirmed
  - Completed by owner through manual execution
- Manual execution command:
  - `docker network rm deploy_default`
- Verification result:
  - `deploy_default` no longer exists
  - `iterlife-expenses-api` remains attached to `iterlife-expenses_default`
  - `iterlife-expenses-ui` remains attached to `iterlife-expenses_default`

## BT Panel Runtime and Runnable Task Detail

### Currently Running Panel-Related Processes

- `BT-Panel`
- `BT-Task`
- `BT-FirewallServices.service`
- periodic `task_script_extension.py` helper tasks

### Panel Scheduling Core

Configured scheduler jobs observed in `task.json`:

1. `jobs:control_task` every 15 seconds
2. `jobs:install_task` every 10 seconds
3. `jobs:site_end_task` every 10800 seconds
4. `jobs:php_safe_task` every 30 seconds

### Runnable Task Surface

The panel script directory exposes many runnable maintenance scripts under `/www/server/panel/script/`, including categories such as:

- firewall and security helpers
- backup and restore helpers
- log rotation and analysis helpers
- certificate and SSL helpers
- database and web server restart helpers
- Docker project backup and restore helpers
- project runtime helpers for Java, Node, and Python

Examples observed:

- `BT-FirewallServices.py`
- `crontab_task_exec.py`
- `docker_compose_backup.py`
- `docker_compose_restore.py`
- `renew_certificate.py`
- `restart_database.py`
- `restart_project.py`
- `rotate_log.py`
- `task_script_extension.py`

### Startup Path

Observed startup hooks and management paths include:

- `/etc/rc.d/init.d/bt`
- `/etc/rc.d/rc2.d/S55bt`
- `/etc/rc.d/rc3.d/S55bt`
- `/etc/rc.d/rc5.d/S55bt`
- `/etc/systemd/system/BT-FirewallServices.service`

This confirms the BT panel surface is still an active host-management subsystem, not only a leftover directory.

## Git Repository Detail

### Production Repositories Under `/apps`

1. `/apps/iterlife-reunion`
   - Owner: `iterlife-reunion:iterlife-reunion`
   - Remote: `git@github.com:LuJie0403/iterlife-reunion.git`
   - Branch: `main`
   - HEAD: `96b0bed82c289da0ac1e93c1ad9fce54880eb04f`
   - Dirty files:
     - `deploy-reunion-from-ghcr.sh`
     - `deploy-reunion-ui-from-ghcr.sh`

2. `/apps/iterlife-reunion-ui`
   - Owner: `iterlife-reunion:iterlife-reunion`
   - Remote: `git@github.com:LuJie0403/iterlife-reunion-ui.git`
   - Branch: `main`
   - HEAD: `6f520a45dbce25d45be01c19c2000d59a9ff3991`
   - Dirty files:
     - none observed

3. `/apps/iterlife-expenses`
   - Owner: `iterlife-reunion:iterlife-reunion`
   - Remote: `git@github.com:LuJie0403/iterlife-expenses.git`
   - Branch: `main`
   - HEAD: `44e75a55b81318c79c36a97e247b8f8ee745243c`
   - Dirty files:
     - none observed

4. `/apps/iterlife-expenses-ui`
   - Owner: `iterlife-reunion:iterlife-reunion`
   - Remote: `git@github.com:LuJie0403/iterlife-expenses-ui.git`
   - Branch: `main`
   - HEAD: `7eb15ab8b0cec2c623efa41570545b98e9df3758`
   - Dirty files:
     - `deploy/compose/expenses-ui.yml`

5. `/apps/iterlife-reunion-stack`
   - Owner: `iterlife-reunion:iterlife-reunion`
   - Remote: `git@github.com:LuJie0403/iterlife-reunion-stack.git`
   - Branch: `main`
   - HEAD: `61fdffa651f04d26194eaa2c3a77d0f6858e7b3b`
   - Dirty files:
     - none observed

### Non-Production Git Repositories Also Present

1. `/home/linuxbrew/.linuxbrew/Homebrew`
   - Third-party tool repository
   - Remote: `https://github.com/Homebrew/brew`
   - Branch: `stable`
   - Not part of IterLife application deployment

2. `/home/lujie/.nvm`
   - Third-party tool repository
   - Remote: `https://github.com/nvm-sh/nvm.git`
   - Detached HEAD at `v0.39.4`
   - Not part of IterLife application deployment

## Current Layout

### `/home`

Observed top-level entries:

- `/home/iterlife-reunion`
- `/home/lujie`
- `/home/www`
- `/home/go`
- `/home/linuxbrew`

Key findings:

- `/home/iterlife-reunion` is a real operator home directory, but it also contains migration leftovers and manual backup folders.
- `/home/lujie` is a separate personal home directory.
- `/home/go` and `/home/linuxbrew` are software/runtime assets placed under `/home`, which blurs ownership.
- `/home/www` exists even though current application runtime is not rooted there.

Space profile:

- `/home`: about `2.1G`
- `/home/iterlife-reunion`: about `1.9G`
- `/home/iterlife-reunion/migration_from_openclaw_expenses_20260227-091717`: about `1.4G`
- `/home/iterlife-reunion/backup`: about `493M`
- `/home/iterlife-reunion/backups`: about `2.6M`

### `/apps`

Observed top-level entries include:

- `/apps/iterlife-reunion`
- `/apps/iterlife-reunion-ui`
- `/apps/iterlife-expenses`
- `/apps/iterlife-expenses-ui`
- `/apps/iterlife-reunion-stack`
- `/apps/config`
- `/apps/data`
- `/apps/logs`
- `/apps/backups`

Key findings:

- `/apps` is the actual production runtime root.
- It holds both runtime assets and full Git working trees.
- Several directories are group-writable (`775`) by default.
- Logs and static directories use `setgid`, which is workable but should be intentional and documented.

### Other Large Directories

Additional large areas outside the requested `/home` scope but relevant to governance:

- `/var`: about `14.8G`
- `/var/lib/docker`: about `9.0G`
- `/var/lib/docker/overlay2`: about `9.8G`
- `/root`: about `2.0G`
- `/www`: about `855M`

These indicate that server governance cannot stop at `/home`; the host should be treated as a whole-system cleanup effort.

## Runtime State

### Running Containers

Observed running containers:

- `iterlife-reunion-ui`
- `iterlife-reunion-api`
- `iterlife-reunion-meili`
- `iterlife-expenses-api`
- `iterlife-expenses-ui`

Container exposure pattern:

- Application containers are bound to `127.0.0.1`
- Nginx terminates inbound traffic on `80/443`
- Webhook service listens on `127.0.0.1:19091`

This is a good baseline pattern for the application path itself.

### systemd Services

Observed active services related to the stack:

- `docker.service`
- `nginx.service`
- `iterlife-app-deploy-webhook.service`
- `iterlife-acme-renew.timer`

Observed additional active system services with governance impact:

- `mysqld.service`
- `redis.service`
- `squid.service`
- `BT-FirewallServices.service`

### Nginx

Nginx is serving:

- `iterlife.com`
- `www.iterlife.com`
- `reunion.iterlife.com`
- `1024.iterlife.com`
- `expenses.iterlife.com`

Current reverse proxy behavior is clear and simple:

- `/hooks/app-deploy` -> `127.0.0.1:19091`
- reunion API -> `127.0.0.1:18080`
- reunion UI -> `127.0.0.1:13080`
- expenses API -> `127.0.0.1:18180`
- expenses UI -> `127.0.0.1:13180`

The host-level traffic path appears healthy.

## Risk Findings

### P0 Security Risks

1. `iterlife-reunion` has unrestricted root escalation.
   - `sudo -l` shows `NOPASSWD: ALL`
   - This makes the application/operator account equivalent to full-root access

2. Duplicate SSH private key material exists in a migration directory.
   - Active key material exists under `/home/iterlife-reunion/.ssh`
   - Additional private key and authorized key copies remain under the migration backup tree

3. Multiple non-app public services are listening on host interfaces.
   - Public listeners observed on `6379`, `3306`, `33060`, `8888`, and `3128`
   - Whether they are internet-reachable depends on ECS security group rules, which were not visible from inside the host

4. SELinux is disabled and `firewalld` is inactive.
   - This is not automatically wrong for every environment
   - But combined with broad sudo and extra public listeners, it reduces defense in depth

### P1 Operational Risks

1. Production server contains live Git repositories.
   - `/apps/iterlife-reunion`
   - `/apps/iterlife-reunion-ui`
   - `/apps/iterlife-expenses`
   - `/apps/iterlife-expenses-ui`
   - `/apps/iterlife-reunion-stack`

2. Production drift is already present.
   - `/apps/iterlife-reunion` has local modifications
   - `/apps/iterlife-expenses-ui` has local modifications
   - This means the host state may diverge from GitHub and deployment automation

3. Backup locations are fragmented.
   - `/home/iterlife-reunion/backup`
   - `/home/iterlife-reunion/backups`
   - `/apps/backups`
   - root-owned backup files also appear inside application-owned areas

4. Historical panel software remains active.
   - `BT-Panel` is listening on `0.0.0.0:8888`
   - `/www/server/panel` is still present and active
   - This introduces another administrative surface outside the documented app deployment path

5. Additional infrastructure services are co-hosted on the same machine.
   - MySQL, Redis, Squid, and panel-related processes all run on the same host
   - This increases the blast radius of any compromise or misconfiguration

### P2 Governance and Hygiene Risks

1. `/home` is being used for both user home data and operational archives.
2. Software assets under `/home/go` and `/home/linuxbrew` reduce clarity.
3. Directory naming is inconsistent: `backup`, `backups`, migration folders, and ad hoc timestamp naming.
4. Group-writable defaults are broader than necessary across `/apps`.
5. `/root` still contains large caches, source trees, and historical build artifacts.

## Recommended Governance Target

The host should converge to the following model:

1. `/apps` contains only production runtime assets.
2. `/home/<user>` contains only user login environment and personal shell state.
3. Source-of-truth code lives in GitHub and CI, not as mutable production working trees.
4. Backups have one canonical root and a retention policy.
5. SSH keys and secrets exist only in their active locations.
6. Application users do not hold unrestricted root privileges.
7. Exposed ports are reduced to the minimum set required by architecture.

## Phased Governance Plan

### Phase 0: Freeze and Validate

Goal: stop drift from getting worse before cleanup.

Actions:

1. Freeze manual production edits on `/apps/*` working trees.
2. Record current Git status for every production repository.
3. Confirm whether local modifications are intentional hotfixes or accidental drift.
4. Confirm which public listeners are intentionally required: `6379`, `3306`, `33060`, `8888`, `3128`.
5. Confirm whether BT panel is still part of the intended operations model.

Approval needed:

- No destructive action yet

### Phase 1: Security Hardening

Goal: reduce compromise blast radius.

Actions:

1. Replace `iterlife-reunion ALL=(ALL) NOPASSWD:ALL` with a least-privilege sudo policy.
2. Remove duplicate SSH private key copies from migration backup directories after verifying active keys.
3. Review ECS security group rules against actual listening ports.
4. Disable or restrict public-facing services that are not required.
5. Decide whether BT panel should be retired, firewalled, or moved to restricted access only.

Approval needed:

- Any sudoers change
- Any SSH key removal
- Any service disablement
- Any security group change

### Phase 2: Directory and Backup Governance

Goal: give every file tree a single purpose.

Actions:

1. Keep `/apps` as the canonical runtime root.
2. Empty or retire `/home/iterlife-reunion/apps`, which is currently an unused shadow path.
3. Move historical migration artifacts out of `/home/iterlife-reunion` into:
   - a single archival root under `/apps/backups/archive`
   - or object storage, then delete local copies
4. Merge `backup` and `backups` into one naming convention and one retention model.
5. Move root-owned nginx backups out of user home backup trees.

Approval needed:

- Deleting or relocating backup archives

### Phase 3: Production Drift Elimination

Goal: ensure production is deploy-only.

Actions:

1. Stop treating `/apps/*` as editable development repositories.
2. Keep only what is required for deployment:
   - compose files
   - deploy scripts
   - environment files
   - runtime data
3. Decide between two models:
   - keep full repos on host but enforce clean working trees and no manual edits
   - or replace repos with deployment-only artifacts
4. Add a routine check that fails if production repos are dirty.

Approval needed:

- Changing deployment model

### Phase 4: Storage Cleanup

Goal: recover space and lower noise safely.

Actions:

1. Prune unused Docker images, especially old GHCR SHA tags and dangling images.
2. Define image retention: keep current running version plus recent rollback versions.
3. Clean `/root` build caches and obsolete source trees if they are no longer needed.
4. Review `/www` and decide whether old panel data and backups are still required.

Approval needed:

- Docker prune operations
- Deleting old `/root` and `/www` artifacts

### Phase 5: Permission Baseline

Goal: make access control intentional.

Recommended baseline:

- Secret env files: `600` or `640`
- User SSH dirs: `700`
- User private keys: `600`
- Code and read-only deploy assets: `755` directories and `644` files
- Writable runtime data: owned by service user, not broadly group-writable by default
- Logs: setgid only where cross-process write sharing is truly needed

## Suggested Immediate Action List

### Safe to Do First

1. Inventory and export current Git dirty state on production repos.
2. Inventory current listening ports and map each one to an owner and purpose.
3. Inventory all backup directories and attach retention labels.
4. Inventory ECS security group rules outside the host.

### Do Next With Explicit Approval

1. Tighten sudoers for `iterlife-reunion`
2. Rotate or remove duplicate SSH private key material
3. Disable BT panel or restrict it to trusted source IPs only
4. Remove unneeded public listeners
5. Prune Docker images
6. Archive and delete migration leftovers

## Decision Items For Owner Confirmation

The following decisions should be confirmed before any cleanup execution:

1. Is BT panel still intentionally in use?
2. Should MySQL, Redis, and Squid remain on this host long term?
3. Are production Git working trees allowed, or should the host become deploy-only?
4. What rollback depth is required for Docker images and backups?
5. Is `/home/lujie` expected to remain on the same production host?

## Audit Boundaries

This audit was performed from inside the host and did not inspect:

- ECS security group configuration in Aliyun control plane
- external DNS control-plane settings
- cloud snapshots or OSS backup policies
- the content of secret files

Those items should be reviewed before finalizing the hardening plan.
