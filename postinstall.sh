#Ce script est un script de post-installation pour une machine Debian/Ubuntu. Il permet d’automatiser plusieurs tâches après l’installation du système :
#✅ Mise à jour du système
#✅ Installation de paquets
#✅ Personnalisation du terminal (.bashrc, .nanorc)
#✅ Sécurisation SSH
#✅ Ajout de clés SSH

#!/bin/bash
#Indique que ce script doit être exécuté avec Bash.

# === VARIABLES ===
# Définit les chemins et fichiers utilisés pendant l’exécution

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")  # Génère un timestamp pour le fichier de log
LOG_DIR="./logs"  # Dossier où seront stockés les logs
LOG_FILE="$LOG_DIR/postinstall_$TIMESTAMP.log"  # Fichier de log avec timestamp
CONFIG_DIR="./config"  # Dossier contenant les fichiers de configuration
PACKAGE_LIST="./lists/packages.txt"  # Fichier contenant la liste des paquets à installer
USERNAME=$(logname)  # Récupère le nom de l’utilisateur connecté
USER_HOME="/home/$USERNAME"  # Chemin vers le home de l'utilisateur

# Définit les chemins et fichiers utilisés pendant l’exécution


# === FUNCTIONS ===
# Écrit dans le fichier de log

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}
# Ajoute un message dans le fichier de log avec timestamp


# Fonction check_and_install : Vérifie si un paquet est installé, sinon l’installe et empêche la réinstallation de paquets déjà installés
check_and_install() {
  local pkg=$1  # Récupère le nom du paquet passé en argument
  if dpkg -s "$pkg" &>/dev/null; then  # Vérifie si le paquet est déjà installé
    log "$pkg is already installed."
  else
    log "Installing $pkg..."
    apt install -y "$pkg" &>>"$LOG_FILE"  # Installe le paquet et enregistre les logs
    if [ $? -eq 0 ]; then  # Vérifie si l'installation a réussi
      log "$pkg successfully installed."
    else
      log "Failed to install $pkg."
    fi
  fi
}


# Fonction ask_yes_no : Demande une confirmation à l’utilisateur
ask_yes_no() {
  read -p "$1 [y/N]: " answer
  case "$answer" in
    [Yy]* ) return 0 ;;  # Si l'utilisateur répond "y" ou "Y", retourne 0 (OK)
    * ) return 1 ;;  # Sinon, retourne 1 (NON)
  esac
}
# Permet d’afficher des questions interactives


# === INITIAL SETUP ===
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
log "Starting post-installation script. Logged user: $USERNAME"


# Vérification de l’utilisateur root
if [ "$EUID" -ne 0 ]; then
  log "This script must be run as root."
  exit 1
fi
# Vérifie si le script est exécuté en tant que root (EUID = ID utilisateur). Sinon, il affiche un message d’erreur et quitte (exit 1).

# === 1. SYSTEM UPDATE ===
log "Updating system packages..."
apt update && apt upgrade -y &>>"$LOG_FILE"
# Met à jour la liste des paquets (apt update) et installe les mises à jour (apt upgrade -y).


# === 2. PACKAGE INSTALLATION ===
if [ -f "$PACKAGE_LIST" ]; then
  log "Reading package list from $PACKAGE_LIST"
  while IFS= read -r pkg || [[ -n "$pkg" ]]; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    check_and_install "$pkg"
  done < "$PACKAGE_LIST"
else
  log "Package list file $PACKAGE_LIST not found. Skipping package installation."
fi
# Vérifie si packages.txt existe, lit la liste et installe chaque paquet avec check_and_install.


# === 3. UPDATE MOTD ===
# Modification du message d’accueil (MOTD)
if [ -f "$CONFIG_DIR/motd.txt" ]; then
  cp "$CONFIG_DIR/motd.txt" /etc/motd
  log "MOTD updated."
else
  log "motd.txt not found."
fi
# Copie un fichier personnalisé (motd.txt) dans /etc/motd pour afficher un message lors de la connexion SSH


# === 4. CUSTOM .bashrc ===
# Personnalisation du .bashrc
if [ -f "$CONFIG_DIR/bashrc.append" ]; then
  cat "$CONFIG_DIR/bashrc.append" >> "$USER_HOME/.bashrc"
  chown "$USERNAME:$USERNAME" "$USER_HOME/.bashrc"
  log ".bashrc customized."
else
  log "bashrc.append not found."
fi
# Ajoute des configurations personnalisées au fichier .bashrc


# === 5. CUSTOM .nanorc ===
# Personnalisation du .nanorc
if [ -f "$CONFIG_DIR/nanorc.append" ]; then
  cat "$CONFIG_DIR/nanorc.append" >> "$USER_HOME/.nanorc"
  chown "$USERNAME:$USERNAME" "$USER_HOME/.nanorc"
  log ".nanorc customized."
else
  log "nanorc.append not found."
fi
# Ajoute des paramètres pour Nano, l’éditeur de texte

# === 6. ADD SSH PUBLIC KEY ===
if ask_yes_no "Would you like to add a public SSH key?"; then
  read -p "Paste your public SSH key: " ssh_key
  mkdir -p "$USER_HOME/.ssh"
  echo "$ssh_key" >> "$USER_HOME/.ssh/authorized_keys"
  chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
  chmod 700 "$USER_HOME/.ssh"
  chmod 600 "$USER_HOME/.ssh/authorized_keys"
  log "SSH public key added."
fi
# Ajoute une clé SSH fournie par l'utilisateur au fichier authorized_keys

# === 7. SSH CONFIGURATION: KEY AUTH ONLY ===
# Sécurisation de SSH
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  systemctl restart ssh
  log "SSH configured to accept key-based authentication only."
else
  log "sshd_config file not found."
fi
# Désactive l’authentification par mot de passe et impose l’usage des clés SSH

log "Post-installation script completed."

exit 0
# Affiche un message de fin et quitte proprement
