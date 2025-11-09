# Installation Guide

This guide will walk you through installing the Website Monitor. The recommended method is using the provided `install.sh` script, which automates dependency installation and setup.

## 1. Recommended: Quick Install Script

1.  **Clone the Repository**
    ```bash
    git clone [https://github.com/YOUR_USERNAME/website-monitor.git](https://github.com/YOUR_USERNAME/website-monitor.git)
    cd website-monitor
    ```

2.  **Run the Installer**
    The script will ask for your `sudo` password to install system packages.
    ```bash
    chmod +x scripts/install.sh
    ./scripts/install.sh
    ```
    
    The installer will:
    * Install system dependencies (`curl`, `html2text`, `nodejs`, `npm`, etc.) using your package manager.
    * Run `scripts/setup-puppeteer.sh` to install Puppeteer in the project directory.
    * Create the user data directory at `~/website_monitor`.
    * Copy the example configuration files (`url_list.txt`, `keywords.txt`) to `~/website_monitor`.

3.  **Next Step**
    Once installed, you're ready to set up your configuration.
    
    ➡️ **Continue to [Configuration Guide](CONFIGURATION.md)**

## 2. Manual Installation

If you prefer to install dependencies yourself:

1.  **Clone the Repository**
    ```bash
    git clone [https://github.com/YOUR_USERNAME/website-monitor.git](https://github.com/YOUR_USERNAME/website-monitor.git)
    cd website-monitor
    ```

2.  **Install System Dependencies**
    You must install the following packages using your system's package manager (e.g., `apt`, `yum`, `brew`):
    * `curl`
    * `html2text`
    * `nodejs`
    * `npm`
    * (Optional but recommended for notifications) `zenity` or `kdialog`

3.  **Setup Puppeteer**
    Run the setup script to install Puppeteer locally in the project:
    ```bash
    chmod +x scripts/setup-puppeteer.sh
    ./scripts/setup-puppeteer.sh
    ```

4.  **Create Data Directory**
    The script stores your personal data in `~/website_monitor`.
    ```bash
    mkdir -p ~/website_monitor
    cp config/url_list.txt.example ~/website_monitor/url_list.txt
    cp config/keywords.txt.example ~/website_monitor/keywords.txt
    ```

5.  **Next Step**
    
    ➡️ **Continue to [Configuration Guide](CONFIGURATION.md)**
