# GLPI Upgrade Script

This repository contains a Bash script designed to automate the upgrade process of a GLPI (Gestionnaire Libre de Parc Informatique) installation. The script handles downloading the latest release, backing up the current installation and database, migrating necessary files, updating the database, and restoring plugins.

> **Warning:** This script is currently in **beta**. Behavior may vary depending on your system configuration, GLPI version, and environment. Please test thoroughly before using in production.

---

## Features

- Automatically fetches the latest GLPI release from GitHub
- Compares current version with latest and skips update if already up-to-date
- Backs up HTML files and MySQL database with version and timestamp
- Migrates configuration, plugins, and assets
- Updates GLPI database
- Reinstalls and reactivates previously active plugins
- Enables and disables maintenance mode
- Color-coded terminal output for clarity
- Rollback mechanism in case of failure

---

## Configuration Variables

These variables are defined at the top of the script and should be customized to match your environment:

| Variable           | Description |
|--------------------|-------------|
| `GLPI_DOWNLOAD_URL` | URL to the latest GLPI release archive (auto-fetched) |
| `LATEST_VERSION`    | Extracted version number from the download URL |
| `GLPI_VERSION`      | Current installed GLPI version (auto-detected) |
| `WEB_ROOT`          | Root directory of your web server (e.g., `/var/www`) |
| `GLPI_OLD_PATH`     | Path to current GLPI installation (e.g., `/var/www/html`) |
| `GLPI_NEW_PATH`     | Temporary path for new GLPI files |
| `GLPI_FINAL_PATH`   | Final path for GLPI after upgrade |
| `DOWNLOAD_DIR`      | Temporary directory for downloading and extracting GLPI |
| `BACKUP_PATH`       | Directory for storing backups (includes version and timestamp) |
| `MYSQL_USER`        | MySQL username for GLPI database |
| `MYSQL_PASSWORD`    | MySQL password for GLPI database |
| `MYSQL_DB`          | Name of the GLPI database |
| `LOG_DIR`           | GLPI log directory |
| `LIB_DIR`           | GLPI library directory |
| `CERT_DIR`          | Directory for certificates |
| `GLPI_ETC_DIR`      | GLPI configuration directory |

---

## Requirements

- Bash script
- Sudo privileges
- PHP CLI
- MySQL client (`mysqldump`)
- wget, tar, grep, cut, tr, xargs

---

## Usage

1. Clone this repository:
   ```bash
   git clone https://github.com/talipcakir/GLPI_auto_update_script.git
   cd GLPI_auto_update_script
   ```

2. Make the script executable:
   ```bash
   chmod +x glpi_auto_update.sh
   ```

3. Run the script with sudo:
   ```bash
   sudo ./glpi_auto_update.sh
   ```

---
