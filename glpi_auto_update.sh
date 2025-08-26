#!/bin/bash

# ==============================
# COLOR DEFINITIONS
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# ==============================
# CONFIGURATION VARIABLES
# ==============================

echo -e "${BLUE}Starting GLPI Upgrade Script...${NC}"

GLPI_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep "browser_download_url" | grep "glpi-.*tgz" | cut -d : -f 2,3 | tr -d \")
GLPI_DOWNLOAD_URL=$(echo "$GLPI_DOWNLOAD_URL" | xargs)
LATEST_VERSION=$(echo "$GLPI_DOWNLOAD_URL" | grep -oP 'glpi-\K[0-9]+\.[0-9]+\.[0-9]+')

WEB_ROOT="/var/www"
GLPI_OLD_PATH="$WEB_ROOT/html"
GLPI_NEW_PATH="$WEB_ROOT/glpi"
GLPI_FINAL_PATH="$WEB_ROOT/html"
DOWNLOAD_DIR="$HOME/glpi_download"
TIMESTAMP=$(date +"%Y%m%d-%H%M")
BACKUP_PATH="$HOME/backup/glpi-$GLPI_VERSION-$TIMESTAMP"
MYSQL_USER="root"
MYSQL_PASSWORD="your_database_password"
MYSQL_DB="glpi"
LOG_DIR="/var/log/glpi"
LIB_DIR="/var/lib/glpi"
CERT_DIR="/etc/certificate"
GLPI_ETC_DIR="/etc/glpi"
GLPI_VERSION=$(php "$GLPI_OLD_PATH/bin/console" --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

# ==============================
# VERSION CHECK
# ==============================

if [ "$GLPI_VERSION" == "$LATEST_VERSION" ]; then
    echo -e "${YELLOW}GLPI is already up-to-date (version $GLPI_VERSION). No upgrade needed.${NC}"
    exit 0
fi

echo -e "${GREEN}Current Version: $GLPI_VERSION | Latest Version: $LATEST_VERSION${NC}"

# ==============================
# SUDO CHECK
# ==============================

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script requires sudo privileges.${NC}"
    sudo -v || { echo -e "${RED}Failed to obtain sudo privileges. Exiting.${NC}"; exit 1; }
fi

# ==============================
# ROLLBACK FUNCTION
# ==============================

rollback() {
    echo -e "${RED}An error occurred. Rolling back changes...${NC}"
    [ -d "$DOWNLOAD_DIR" ] && sudo rm -rf "$DOWNLOAD_DIR" && echo -e "${YELLOW}Cleaned download directory.${NC}"
    if [ -d "${GLPI_OLD_PATH}_old" ]; then
        sudo rm -rf "$GLPI_FINAL_PATH"
        sudo mv "${GLPI_OLD_PATH}_old" "$GLPI_OLD_PATH"
        echo -e "${YELLOW}Restored previous GLPI directory.${NC}"
    fi
    php "$GLPI_OLD_PATH/bin/console" glpi:maintenance:disable >/dev/null 2>&1 && echo -e "${YELLOW}Maintenance mode disabled.${NC}"
    exit 1
}

check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: $1${NC}"
        rollback
    fi
}

# ==============================
# STEP 1: DOWNLOAD LATEST GLPI
# ==============================

echo -e "${BLUE}Downloading latest GLPI version...${NC}"
sudo mkdir -p "$DOWNLOAD_DIR"
check_error "Failed to create download directory."
cd "$DOWNLOAD_DIR"
sudo wget -q "$GLPI_DOWNLOAD_URL"
check_error "Failed to download GLPI."

# ==============================
# STEP 2: EXTRACT AND CLEANUP
# ==============================

echo -e "${BLUE}Extracting GLPI archive...${NC}"
sudo tar -xzvf glpi-*.tgz
check_error "Failed to extract GLPI archive."
rm glpi-*.tgz

# ==============================
# STEP 3: MOVE NEW GLPI
# ==============================

echo -e "${BLUE}Moving new GLPI folder...${NC}"
sudo mv -f "$DOWNLOAD_DIR/glpi" "$GLPI_NEW_PATH"
check_error "Failed to move GLPI folder."

# ==============================
# STEP 4: COPY NECESSARY FILES
# ==============================

echo -e "${BLUE}Copying necessary files...${NC}"
for dir in config files marketplace plugins; do
    sudo mkdir -p "$GLPI_NEW_PATH/$dir"
    sudo cp -rf "$GLPI_OLD_PATH/$dir" "$GLPI_NEW_PATH/"
    check_error "Failed to copy $dir files."
done
sudo cp -f "$GLPI_OLD_PATH/inc/downstream.php" "$GLPI_NEW_PATH/inc/downstream.php"
check_error "Failed to copy downstream.php."

# ==============================
# STEP 5: COPY OTHER FILES
# ==============================

echo -e "${BLUE}Copying additional files...${NC}"
files_to_copy=(
    "css/palettes/iso_default.scss"
    "css/palettes/iso_red.scss"
    ".htaccess"
    "front/.htaccess"
    "pics/favicon.ico"
    "pics/glpi.png"
    "pics/login_logo_glpi.png"
    "pics/fd_logo.png"
)
for file in "${files_to_copy[@]}"; do
    sudo mkdir -p "$(dirname "$GLPI_NEW_PATH/$file")"
    sudo cp -f "$GLPI_OLD_PATH/$file" "$GLPI_NEW_PATH/$file"
    check_error "Failed to copy $file."
done
sudo cp -rf "$GLPI_OLD_PATH/pics/logos" "$GLPI_NEW_PATH/pics/"
check_error "Failed to copy logos directory."

# ==============================
# STEP 6: SET PERMISSIONS
# ==============================

echo -e "${BLUE}Setting permissions...${NC}"
sudo chown -R www-data:www-data "$LOG_DIR" "$LIB_DIR" "$CERT_DIR" "$GLPI_ETC_DIR" "$GLPI_OLD_PATH" "$GLPI_NEW_PATH"
sudo chmod -R 755 "$LOG_DIR" "$LIB_DIR" "$CERT_DIR" "$GLPI_ETC_DIR" "$GLPI_OLD_PATH" "$GLPI_NEW_PATH"
check_error "Failed to set permissions."

# ==============================
# STEP 7: ENABLE MAINTENANCE MODE
# ==============================

echo -e "${BLUE}Enabling maintenance mode...${NC}"
php "$GLPI_OLD_PATH/bin/console" glpi:maintenance:enable
check_error "Failed to enable maintenance mode."

# ==============================
# STEP 8: BACKUP
# ==============================

echo -e "${BLUE}Creating backup...${NC}"
mkdir -p "$BACKUP_PATH"
mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" > "$BACKUP_PATH/glpi-db-$GLPI_VERSION.sql"
check_error "Failed to backup database."
sudo cp -r "$GLPI_OLD_PATH" "$BACKUP_PATH/html-$GLPI_VERSION"
check_error "Failed to backup HTML files."

# Get active plugins BEFORE database update
directories=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE $MYSQL_DB; SELECT GROUP_CONCAT(directory) AS directories FROM glpi_plugins WHERE state = 1;" | tail -n 1)

sudo mv "$GLPI_OLD_PATH" "${GLPI_OLD_PATH}_old"
check_error "Failed to move old HTML directory."
sudo mv "$GLPI_NEW_PATH" "$GLPI_FINAL_PATH"
check_error "Failed to move new GLPI directory."

# ==============================
# STEP 9: UPDATE DATABASE
# ==============================

echo -e "${BLUE}Updating database...${NC}"
php "$GLPI_FINAL_PATH/bin/console" db:update
check_error "Database update failed."

# ==============================
# STEP 10: INSTALL & ACTIVATE PLUGINS
# ==============================

echo -e "${BLUE}Installing and activating plugins...${NC}"
IFS=',' read -ra PLUGINS <<< "$directories"
for plugin in "${PLUGINS[@]}"; do
    plugin=$(echo "$plugin" | xargs)
    if [ -n "$plugin" ]; then
        php "$GLPI_FINAL_PATH/bin/console" glpi:plugin:install "$plugin" --username "glpi" || true
        php "$GLPI_FINAL_PATH/bin/console" glpi:plugin:activate "$plugin" || true
        check_error "Plugin $plugin activation failed."
    fi
done
php "$GLPI_FINAL_PATH/bin/console" glpi:cache:clear
check_error "Failed to clear cache."

# ==============================
# STEP 11: FINAL PERMISSIONS
# ==============================

echo -e "${BLUE}Resetting permissions...${NC}"
sudo chown -R www-data:www-data "$LOG_DIR" "$LIB_DIR" "$CERT_DIR" "$GLPI_ETC_DIR" "$GLPI_FINAL_PATH"
sudo chmod -R 755 "$LOG_DIR" "$LIB_DIR" "$CERT_DIR" "$GLPI_ETC_DIR" "$GLPI_FINAL_PATH"
check_error "Failed to reset permissions."

# ==============================
# STEP 12: DISABLE MAINTENANCE MODE
# ==============================

echo -e "${BLUE}Disabling maintenance mode...${NC}"
php "$GLPI_FINAL_PATH/bin/console" glpi:maintenance:disable
check_error "Failed to disable maintenance mode."

# ==============================
# STEP 13: CLEANUP
# ==============================

echo -e "${BLUE}Cleaning up old files...${NC}"
sudo rm -rf "${GLPI_OLD_PATH}_old"
check_error "Failed to remove old HTML directory."
sudo mv "$GLPI_FINAL_PATH/install" "$GLPI_FINAL_PATH/.install"
check_error "Failed to move install directory."

echo -e "${GREEN} GLPI has been successfully upgraded to version $LATEST_VERSION!${NC}"
