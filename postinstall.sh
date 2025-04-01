#Ce script est un script de post-installation pour une machine Debian/Ubuntu. Il permet d’automatiser plusieurs tâches après l’installation du système :
#✅ Mise à jour du système
#✅ Installation de paquets
#✅ Personnalisation du terminal (.bashrc, .nanorc)
#✅ Sécurisation SSH
#✅ Ajout de clés SSH

#!/bin/bash

# === VARIABLES ===
TIMESTAMP=$(date +"%Y%m%d_%H%M%S") # generates a timestamp in the format YYYYMMDD_HHMMSS
LOG_DIR="./logs" # directory for logs
LOG_FILE="$LOG_DIR/postinstall_$TIMESTAMP.log" #  Path to the log file, named with the current timestamp
CONFIG_DIR="./config" # where the config dir is located
PACKAGE_LIST="./lists/packages.txt" # list of packages to install, which is found at /lists/packages.txt
USERNAME=$(logname) # logged in user
USER_HOME="/home/$USERNAME" # define the home directory of the logged in user

# === FUNCTIONS ===
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" # Generates a timestamp for each log entry
}

check_and_install() {
  local pkg=$1
  if dpkg -s "$pkg" &>/dev/null; then
    log "$pkg is already installed." # if the package is already installed, it will skip the installation
  else
    log "Installing $pkg..."
    apt install -y "$pkg" &>>"$LOG_FILE" # install the package and log the output
    if [ $? -eq 0 ]; then
      log "$pkg successfully installed." # if the package is successfully installed, it will log it
    else
      log "Failed to install $pkg." # if the package installation fails, it will log it
    fi
  fi
}

ask_yes_no() {
  read -p "$1 [y/N]: " answer  # prompt the user for a yes/no question
  case "$answer" in 
    [Yy]* ) return 0 ;;
    * ) return 1 ;;
  esac
}

# === INITIAL SETUP ===
mkdir -p "$LOG_DIR" # create the log directory 
touch "$LOG_FILE" # create the log file
log "Starting post-installation script. Logged user: $USERNAME" # log the start of the script using the logged-in user

if [ "$EUID" -ne 0 ]; then  # check if the script is run as root
  log "This script must be run as root." # if not, log the error
  exit 1 # exit the script with an error code
fi

# === 1. SYSTEM UPDATE ===
log "Updating system packages..." # Log the update start
if ! apt update && apt upgrade -y >> "$LOG_FILE" 2>&1; then
    log "Une erreur est survenue lors de la mise à jour"
    exit 1
fi

# === 2. PACKAGE INSTALLATION ===
if [ -f "$PACKAGE_LIST" ]; then # check if the package list file exists 
  log "Reading package list from $PACKAGE_LIST" # read the package list 
  while IFS= read -r pkg || [[ -n "$pkg" ]]; do  # read each line of the package list
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    check_and_install "$pkg"
  done < "$PACKAGE_LIST"
else
  log "Package list file $PACKAGE_LIST not found. Skipping package installation."
fi

# === 3. UPDATE MOTD ===
if [ -f "$CONFIG_DIR/motd.txt" ]; then # file found in the config directory to set the motd
  cp "$CONFIG_DIR/motd.txt" /etc/motd # copy the motd file to the /etc directory
  log "MOTD updated." # log the update
else
  log "motd.txt not found." # if motd.txt not found, log it
fi

# === 4. CUSTOM .bashrc === # customize the bashrc file, customize at your own risks
if [ -f "$CONFIG_DIR/bashrc.append" ]; then # check if the bashrc.append file exists
  cat "$CONFIG_DIR/bashrc.append" >> "$USER_HOME/.bashrc" # cat the bashrc is $CONFIG_DIR and then append the contents of bashrc.append to the user's .bashrc
  chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc" # change ownership of the .bashrc file to the user
  log ".bashrc customized." # log the customization
else
  log "bashrc.append not found." # if bashrc.append not found, log it
fi

# === 5. CUSTOM .nanorc === # customize the nanorc file, customize at your own risks
if [ -f "$CONFIG_DIR/nanorc.append" ]; then # check if the nanorc.append file exists
  cat "$CONFIG_DIR/nanorc.append" >> "$USER_HOME/.nanorc" # append the contents of nanorc.append to the user's .nanorc
  chown "$USERNAME:$USERNAME" "$USER_HOME/.nanorc" # change ownership of the .nanorc file to the user
  log ".nanorc customized." # log the customization
else
  log "nanorc.append not found." # if nanorc.append not found, log it
fi

# === 6. ADD SSH PUBLIC KEY ===
if ask_yes_no "Would you like to add a public SSH key?"; then # ask the user if they want to add a public SSH key
  read -p "Paste your public SSH key: " ssh_key # prompt the user to paste their public SSH key
  mkdir -p "$USER_HOME/.ssh"  # create the .ssh directory 
  echo "$ssh_key" >> "$USER_HOME/.ssh/authorized_keys" # append the SSH key to the authorized_keys file
  chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh" # change ownership of the .ssh directory to the user
  chmod 700 "$USER_HOME/.ssh" # set permissions for the .ssh directory
  chmod 600 "$USER_HOME/.ssh/authorized_keys" # set permissions for the authorized_keys file
  log "SSH public key added." # log the addition of the SSH key
fi

# === 7. SSH CONFIGURATION: KEY AUTH ONLY ===
if [ -f /etc/ssh/sshd_config ]; then # check if the sshd_config file exists
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config # disable password authentication
  sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config # disable challenge-response authentication
  sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config # enable public key authentication
  systemctl restart ssh # restart the SSH service
  log "SSH configured to accept key-based authentication only." # log the configuration
else 
  log "sshd_config file not found." # if sshd_config file not found, log it
fi

log "Post-installation script completed." # log the completion of the script

exit 0 # exit the script with a success code
