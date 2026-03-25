# webhook config location

Runtime config has been moved out of the repository path.

- Real env file: `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`
- Example file in repo: `./iterlife-deploy-webhook.env.example`
- Runtime log directory: `/apps/logs/webhook`
- Runtime log file pattern: `/apps/logs/webhook/iterlife-deploy-webhook-YYYY-MM-DD.log`

The Python webhook service is responsible for:

- creating `/apps/logs/webhook` on startup if it does not exist
- creating the current day's log file before serving requests
- rolling over to a new daily log file automatically when the date changes

The systemd unit writes stdout and stderr to `journalctl`; deployment and HTTP
events are written by the Python process into the daily log file.
