# 🌐 Website Monitor

A powerful, feature-rich Bash-based website monitoring tool that detects changes, tracks keywords, and provides real-time alerts with desktop notifications.

![Website Monitor](docs/screenshots/demo.png)

## ✨ Features

- **🔄 Smart Change Detection**: Advanced diff-based monitoring with content hashing
- **🔍 Keyword Tracking**: Classify and categorize changes with custom keywords
- **🤖 JavaScript Support**: Full Puppeteer integration for SPAs and modern web apps
- **📊 Beautiful Reports**: HTML reports with categorized changes and visual indicators
- **🔔 Multi-channel Alerts**: Desktop notifications (Zenity/KDialog), Telegram, and console alerts
- **⚙️ Zone Monitoring**: Monitor specific page sections with configurable zones
- **🕒 Automation Ready**: systemd, cron, and manual operation modes
- **🔧 Diagnostic Tools**: Comprehensive debugging and testing utilities

## 🚀 Quick Start

### Prerequisites
- Ubuntu 18.04+, Debian 10+, or compatible Linux distribution
- Bash 4.0+
- Node.js 14+ (for Puppeteer support)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/website-monitor.git
cd website-monitor

# Run the installation script
chmod +x scripts/install.sh
./scripts/install.sh
