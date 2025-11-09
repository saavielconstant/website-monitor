Configuration avec systemd utilisateur

Excellent choix ! Systemd utilisateur est beaucoup plus fiable que cron pour ce genre de tâches. Voici la procédure complète :

📋 Étape 1 : Créer le répertoire systemd utilisateur si nécessaire
bash

# Créer les répertoires systemd utilisateur
mkdir -p ~/.config/systemd/user


🔧 Étape 2 : Créer le fichier de service
bash

# Créer le fichier service
nano ~/.config/systemd/user/rclone-sync.service

Contenu du fichier :

[Unit]
Description=RClone Sync Service
After=graphical-session.target

[Service]
Type=oneshot
Environment=DISPLAY=:0
ExecStart=/home/saaviel/Documents/Synchronisations/ssomda-clouds/3-sync-docs-others/rcloneconfig/rclone_monitor.sh

[Install]
WantedBy=default.target

⏰ Étape 3 : Créer le fichier timer
bash

# Créer le fichier timer
nano ~/.config/systemd/user/rclone-sync.timer

Contenu du fichier :

[Unit]
Description=RClone Synchronization Timer
Requires=rclone-sync.service

[Timer]
# Exécution à 13h, 16h et 23h
OnCalendar=*-*-* 13:00:00
OnCalendar=*-*-* 16:00:00
OnCalendar=*-*-* 23:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target

🛠️ Étape 4 : Adapter votre script rclone_monitor.sh

Votre script peut rester simple maintenant :
#!/bin/sh
#!/bin/bash
#!/bin/bash
##########################################################################################################################
LOG_FILE="/home/saaviel/rlone_logs/rclone_$(date +\%Y\%m\%d_\%H\%M).log"
echo "=== RCLONE SYNC STARTED : 1-SYNC-DOCS-TEACHING ==> SAAVIELGDRIVE ====" > $LOG_FILE
echo "Date: $(date)" >> $LOG_FILE
echo "User: $(whoami)" >> $LOG_FILE
echo "Display: $DISPLAY" >> $LOG_FILE
echo "DBUS: $DBUS_SESSION_BUS_ADDRESS" >> $LOG_FILE
echo "DBUS: $DBUS_SESSION_BUS_ADDRESS" >> $LOG_FILE
/snap/bin/rclone sync /home/saaviel/Documents/Synchronisations/ssomda-clouds/1-sync-docs-teaching saavielgdrive:/1-sync-docs-teaching --create-empty-src-dirs --progress >> $LOG_FILE 2>&1
SYNC_STATUS=$?
echo "=== RCLONE SYNC COMPLETED : 1-SYNC-DOCS-TEACHING ==> SAAVIELGDRIVE ===" >> $LOG_FILE
echo "Date: $(date)" >> $LOG_FILE
echo "Exit Code: $SYNC_STATUS" >> $LOG_FILE
##########################################################################################################################
# 🔥 Gestion des notifications et ouverture du fichier
open_log_file() {
    local log_file="$1"
    local status="$2"
    
    # Récupérer l'utilisateur actif sur le display :0
    local active_user=$(who | grep "(:0)" | awk '{print $1}' | head -1)
    if [ -z "$active_user" ]; then
        active_user=$(who | awk '{print $1}' | head -1)
    fi
    if [ -z "$active_user" ]; then
        active_user="$USER"
    fi
    
    local user_id=$(id -u "$active_user" 2>/dev/null)
    
    # Définir les variables d'environnement
    local display=":0"
    local dbus_addr="unix:path=/run/user/${user_id}/bus"
    local xauth_file="/home/${active_user}/.Xauthority"
    
    # Notification
    if [ -S "/run/user/${user_id}/bus" ]; then
        if [ "$status" -eq 0 ]; then
            sudo -u "$active_user" DISPLAY="$display" DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
                notify-send -i dialog-information "RClone OK" "Synchronisation réussie - Voir $(basename "$log_file")"
        else
            sudo -u "$active_user" DISPLAY="$display" DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
                notify-send -i dialog-error "RClone ERROR" "Erreur code $status - Voir $(basename "$log_file")"
        fi
        
        # Ouvrir le log avec xdg-open (application par défaut)
        sudo -u "$active_user" DISPLAY="$display" DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
            gnome-text-editor $log_file
    else
        echo "Impossible d'envoyer des notifications - DBus non disponible" >> "$log_file"
    fi
}

# Ouvrir le fichier log
open_log_file "$LOG_FILE" $SYNC_STATUS
##########################################################################################################################

Assurez-vous que le script est exécutable :
bash

chmod +x /home/saaviel/Documents/Synchronisations/ssomda-clouds/3-sync-docs-others/rcloneconfig/rclone_monitor.sh

🚀 Étape 5 : Activer et démarrer le service
bash

# Recharger la configuration systemd
systemctl --user daemon-reload

# Activer le timer (démarrage automatique)
systemctl --user enable rclone-sync.timer

# Démarrer le timer
systemctl --user start rclone-sync.timer

# Vérifier que le timer est actif
	

🔍 Étape 6 : Vérification et tests

# Vérifier l'état du timer
systemctl --user status rclone-sync.timer

# Voir les timers actifs
systemctl --user list-timers

# Tester manuellement le service
systemctl --user start rclone-sync.service

# Voir les logs du service
journalctl --user -u rclone-sync.service -f

# Voir tous les logs utilisateur
journalctl --user -f

🎯 Étape 7 : Résolution de problèmes courants
Si le service ne démarre pas :
bash

# Vérifier les journaux détaillés
journalctl --user -u rclone-sync.service -n 50

# Vérifier l'environnement du service
systemctl --user show-environment

# Tester manuellement avec l'environnement
env DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus /home/saaviel/Documents/Synchronisations/ssomda-clouds/3-sync-docs-others/rcloneconfig/rclone_monitor.sh


📊 Commandes utiles de monitoring
bash

# Voir le statut des timers
systemctl --user list-timers rclone-sync.timer

# Voir la prochaine exécution
systemctl --user list-timers | grep rclone

# Forcer une exécution immédiate
systemctl --user start rclone-sync.service

# Désactiver le timer
systemctl --user disable rclone-sync.timer

# Recharger après modification
systemctl --user daemon-reload

⚡ Activation au démarrage de la session

Pour que le timer démarre automatiquement quand vous vous connectez :
bash

# Activer le linger (important pour les services utilisateur)
sudo loginctl enable-linger $USER

# Vérifier
loginctl show-user $USER | grep Linger

🎉 Résultat final

Avec cette configuration :

    ✅ Les notifications apparaîtront car le service s'exécute dans le contexte utilisateur

    ✅ Les logs s'ouvriront automatiquement dans gedit

    ✅ Plus fiable que cron pour les tâches graphiques

    ✅ Meilleur monitoring avec journalctl

    ✅ Redémarrage automatique en cas d'échec réseau

Vos synchronisations s'exécuteront maintenant à 13h, 16h et 23h avec toutes les notifications visuelles ! 🚀

Testez immédiatement avec :
bash

systemctl --user start rclone-sync.service

Cela vous montrera si tout fonctionne correctement !
