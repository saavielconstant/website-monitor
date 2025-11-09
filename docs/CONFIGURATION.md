# Configuration Guide

The Website Monitor separates its core logic (in the project folder) from your personal data (in `~/website_monitor`). All configuration happens in the `~/website_monitor` directory.

## 1. Main Configuration

### `~/website_monitor/url_list.txt`
This is the list of all websites you want to monitor.
* Add one URL per line.
* Lines starting with `#` are ignored.

```ini
# This is a comment
[https://www.example.com](https://www.example.com)
[https://github.com/trending](https://github.com/trending)
```

### '~/website_monitor/keywords.txt'

This file defines the keywords the script will look for in new changes.

The format is keyword|description.

The keyword is what the script searches for (case-insensitive). It can be a single word or a phrase.

The description is used to categorize the change in the final HTML report.

```ini
# Format: keyword|description
recrutement|Job Offers, Recruitment
offre d emploi|Job Announcements
promotion|Sales and Promotions
```
You can also manage this file interactively using the --keywords command: 

```bash
./src/website-monitor.sh --keywords
```

## 2. Advanced Configuration

zone_config.conf (Per-URL Tuning)

This is the most powerful feature. For each URL, a snapshot directory is created (e.g., ~/website_monitor/snapshots/<hash>). Inside, you will find a zone_config.conf file.

You can edit this file to change the monitoring behavior for that specific URL.

Options:

    ZONE_MODE:

        "full": (Default) Monitors the entire page.

        "between": Monitors only the content between ZONE_START and ZONE_END.

        "before": Monitors everything after ZONE_START.

        "after": Monitors everything before ZONE_END.

    FORCE_PUPPETEER:

        "false": (Default) Uses curl.

        "true": Forces the use of Puppeteer for this site. Use this for sites that rely heavily on JavaScript (React, Angular, etc.).

    ZONE_START / ZONE_END:

        The text or HTML markers to use for between, before, or after modes.

Example 1: Monitoring a News Site's Main Article (See examples/custom-zones/news-site-zone.conf)

```ini
# Monitor only the article, ignore ads and comments
ZONE_MODE="between"
ZONE_START="<article class=\"main-content\">"
ZONE_END="<div class=\"comments-section\">"
FORCE_PUPPETEER="false"
```

Example 2: Monitoring a JavaScript App (See examples/custom-zones/react-app-zone.conf)

```
# This site needs JavaScript to load
ZONE_MODE="full"
FORCE_PUPPETEER="true"
```

Telegram Alerts

You can receive instant notifications on Telegram.

    Create a Telegram Bot (talk to @BotFather on Telegram).

    Get your BOT_TOKEN.

    Get your CHAT_ID (talk to @userinfobot).

    Edit src/website-monitor.sh and update these variables:

```bash
# Configuration des alertes Telegram
TELEGRAM_BOT_TOKEN="votre_bot_token_ici"
TELEGRAM_CHAT_ID="votre_chat_id_ici"
ENABLE_TELEGRAM_ALERTS=true
```
(You can also move this configuration to an external file like examples/telegram-config.sh and source it from the main script for better privacy).
