# Troubleshooting & Utilities

This guide covers common issues and helpful utility commands built into the script.

## 1. Command-Line Utilities

You can run the script with these flags for diagnostics and management:

* `./src/website-monitor.sh --diagnose <URL>`
    This is the most important tool. It tests a single URL with both `curl` and `Puppeteer`, shows you the output size, and helps you decide if you need to set `FORCE_PUPPETEER="true"`.

* `./src/website-monitor.sh --list-urls`
    Lists all URLs you are monitoring, along with their `hash` and snapshot directory location. This is useful for finding the correct `zone_config.conf` file to edit.

* `./src/website-monitor.sh --keywords`
    Starts an interactive menu to add, remove, or modify your keywords. It also includes an option to **test a keyword against a live URL** to see if it's found.

* `./src/website-monitor.sh --install-deps`
    A shortcut to run the system dependency installer (requires `sudo`).

## 2. Common Problems

**Problem: I get alerts for a site, but the `diff` looks empty or is just a date/timestamp.**
* **Solution:** Your `ZONE_MODE` is too broad. Edit the site's `zone_config.conf` and use `ZONE_MODE="between"` to monitor *only* the specific content area you care about, excluding headers, footers, or sidebars.

**Problem: A site (e.g., a React app) shows no content or is blank.**
* **Solution:** The site requires JavaScript.
    1.  Run `./src/website-monitor.sh --diagnose <URL>` to confirm. You will likely see `curl` has 0 content and `Puppeteer` has content.
    2.  Find the site's `zone_config.conf` (use `--list-urls`).
    3.  Edit the file and set `FORCE_PUPPETEER="true"`.

**Problem: Desktop notifications (`zenity`) don't appear when run with `systemd` or `cron`.**
* **Solution:** The automation tool doesn't know where your "desktop" is.
    * **For Systemd:** Ensure your `website-monitor.service` file includes `Environment=DISPLAY=:0` and `Environment=DBUS_SESSION_BUS_ADDRESS=...`. (Our template includes this).
    * **For Cron:** Make sure you prepend `export DISPLAY=:0` before the script command in your `crontab`.

**Problem: Puppeteer fails to run.**
* **Solution:** The local Puppeteer module may be missing or corrupted.
    1.  Run the setup script again: `./scripts/setup-puppeteer.sh`
    2.  If it still fails, try deleting the `puppeteer_module` directory and re-running the script.
