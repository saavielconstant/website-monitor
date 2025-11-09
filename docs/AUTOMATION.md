# Automation Guide

To be effective, the monitor should run on a schedule. Here are the two recommended methods.

**IMPORTANT:** For desktop notifications (Zenity/KDialog) to work, the script needs access to your graphical environment. This is why we add `Environment=DISPLAY=:0` (for systemd) or `export DISPLAY=:0` (for cron).

## 1. Systemd (Recommended)

This method is robust and handles logging automatically. We will create a **user service** (no `sudo` required) to run in your session.

### 1.  **Copy the Service Files**
    Copy the provided template files from the project to your systemd user directory:
    ```bash
    mkdir -p ~/.config/systemd/user/
    cp systemd/website-monitor.service ~/.config/systemd/user/
    cp systemd/website-monitor.timer ~/.config/systemd/user/
    ```

### 2.  **Edit the `.service` File**
    You **must** update the path to your script.

    ```bash
    nano ~/.config/systemd/user/website-monitor.service
    ```
    Change this line to the **absolute path** of the script:
    `ExecStart=/home/YOUR_USER/path/to/website-monitor/src/website-monitor.sh`

### 3.  **Enable and Start the Timer**
    ```bash
    # Reload systemd to read the new files
    systemctl --user daemon-reload
    
    # Enable the timer to start on boot
    systemctl --user enable website-monitor.timer
    
    # Start the timer now
    systemctl --user start website-monitor.timer
    ```

### 4.  **Check the Status**
    * To see your timers: `systemctl --user list-timers`
    * To see the logs: `journalctl --user -u website-monitor.service -f`

## 2. Cron (Classic)

### 1.  **Open your crontab:**
    ```bash
    crontab -e
    ```

### 2.  **Add the Cron Job**
    Add the line from the `cron/website-monitor.cron` example, making sure to update the path. This example runs every 30 minutes.

    ```crontab
    # Run website-monitor every 30 minutes
    */30 * * * * export DISPLAY=:0 && /home/YOUR_USER/path/to/website-monitor/src/website-monitor.sh
    ```

### 3.  **Check the Logs**
    Cron logs are typically in `/var/log/syslog` or you can redirect the script's output to its own log file:
    ```crontab
    */30 * * * * ... > /home/YOUR_USER/website_monitor/cron.log 2>&1
    ```
