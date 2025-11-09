#!/bin/bash

# =============================================================================
# PATHS DU PROJET
# =============================================================================
# Trouver le répertoire du script (src)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# La racine du projet est un dossier au-dessus
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Chemin vers le module Puppeteer (géré par install.sh)
PUPPETEER_MODULE_DIR="$PROJECT_ROOT/puppeteer_module"

# Chemin vers les configurations d'exemple
CONFIG_DIR="$PROJECT_ROOT/config"

# =============================================================================
# CONFIGURATION
# =============================================================================
# Configuration des dossiers et fichiers de travail
BASE_DIR="$HOME/website_monitor"
URL_LIST_FILE="$BASE_DIR/url_list.txt"
LOG_FILE="$BASE_DIR/global_change.log"
HTML_REPORT_FILE="$BASE_DIR/changes_report.html"

# Configuration des options CurL
CURL_OPTIONS="--connect-timeout 10 -L -s"

# Configuration des alertes Telegram
TELEGRAM_BOT_TOKEN="votre_bot_token_ici"
TELEGRAM_CHAT_ID="votre_chat_id_ici"
ENABLE_TELEGRAM_ALERTS=false

# Configuration Puppeteer
# Le script JS est maintenant dans src/, pas généré dans BASE_DIR
PUPPETEER_SCRIPT="$PROJECT_ROOT/src/puppeteer_fetch.js" 
PUPPETEER_TIMEOUT=120000 
ENABLE_PUPPETEER=false

# Configuration des mots-clés
KEYWORDS_FILE="$BASE_DIR/keywords.txt" # L'utilisateur modifie celui-ci
KEYWORDS_RESULTS_FILE="$BASE_DIR/keywords_results.txt"

# Variables globales pour le suivi des changements
CHANGES_DETECTED=false
ANY_CHANGE_DETECTED=false

# =============================================================================
# FONCTIONS DE NOTIFICATION ET OUVERTURE 
# =============================================================================
# Fonction pour envoyer des notifications desktop (version optimisée)
send_desktop_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    
    echo "🔔 Notification: $title - $mehttps://jobivoire.ci/jobsssage"
    
    # Priorité 1: Zenity (fonctionne sur votre système)
    if command -v zenity >/dev/null 2>&1; then
        # Adapter l'icône selon l'urgence
        local icon="dialog-information"
        case "$urgency" in
            critical) icon="dialog-error" ;;
            low) icon="dialog-information" ;;
        esac
        
        zenity --notification \
               --window-icon="$icon" \
               --text="$title: $message" \
               --timeout=10 2>/dev/null &
        
        # Alternative: popup complète pour les alertes critiques
        if [ "$urgency" = "critical" ]; then
            zenity --info \
                   --title="$title" \
                   --text="$message" \
                   --width=400 \
                   --timeout=10 2>/dev/null &
        fi
        
        echo "✅ Notification envoyée via zenity"
        return 0
    fi
    
    # Priorité 2: KDialog (fonctionne aussi sur votre système)
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --title "$title" \
                --passivepopup "$message" 10 2>/dev/null &
        echo "✅ Notification envoyée via kdialog"
        return 0
    fi
    
    # Priorité 3: notify-send (avec installation du daemon)
    if command -v notify-send >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
        # Vérifier si un daemon de notification est actif
        if ps aux | grep -v grep | grep -q "notification-daemon\|dunst\|notify-osd\|xfce4-notifyd\|mako\|deadd"; then
            notify-send -u "$urgency" -t 10000 "$title" "$message"
            echo "✅ Notification envoyée via notify-send"
            return 0
        fi
    fi
    
    # Fallback: Affichage console très visible
    local color_start=""
    local color_end=""
    
    # Couleurs selon l'urgence
    case "$urgency" in
        critical)
            color_start="\033[1;41;97m"  # Rouge vif, texte blanc gras
            ;;
        normal)
            color_start="\033[1;44;97m"  # Bleu, texte blanc gras
            ;;
        low)
            color_start="\033[1;42;97m"  # Vert, texte blanc gras
            ;;
    esac
    color_end="\033[0m"
    
    echo ""
    echo -e "${color_start}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  🔔 $title"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  $message"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${color_end}"
    echo ""
    
    # Jouer un son si possible
    if command -v paplay >/dev/null 2>&1; then
        paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null &
    fi
    
    return 0
}

# Fonction pour ouvrir le rapport HTML (version optimisée)
open_html_report() {
    local html_file="$1"
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  🌐 OUVERTURE DU RAPPORT HTML                                  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    
    # Vérifier que le fichier existe
    if [ ! -f "$html_file" ]; then
        echo "❌ Fichier non trouvé: $html_file"
        return 1
    fi
    
    local file_size=$(stat -c%s "$html_file" 2>/dev/null || stat -f%z "$html_file" 2>/dev/null)
    local abs_path=$(realpath "$html_file" 2>/dev/null || readlink -f "$html_file" 2>/dev/null || echo "$html_file")
    
    echo "📄 Fichier: $abs_path"
    echo "📊 Taille: $file_size bytes"
    echo ""
    
    # Priorité 1: xdg-open (fonctionne sur votre système selon le diagnostic)
    if command -v xdg-open >/dev/null 2>&1; then
        echo "🚀 Ouverture avec xdg-open..."
        xdg-open "$abs_path" >/dev/null 2>&1 &
        sh -c "/home/saaviel/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/start-tor-browser" "$abs_path" >/dev/null 2>&1 &
        sleep 3
        echo "✅ Commande xdg-open exécutée"
        echo ""
        echo "╚════════════════════════════════════════════════════════════════╝"
        return 0
    fi
    
    # Priorité 2: Navigateurs directs
    local browsers=("firefox" "google-chrome" "chromium" "chromium-browser" "brave-browser")
    
    for browser in "${browsers[@]}"; do
        if command -v "$browser" >/dev/null 2>&1; then
            echo "🚀 Tentative avec $browser..."
            
            case "$browser" in
                firefox)
                    $browser --new-tab "$abs_path" 2>/dev/null &
                    ;;
                *)
                    $browser --new-window "$abs_path" 2>/dev/null &
                    ;;
            esac
            
            local browser_pid=$!
            sleep 3
            
            if ps -p $browser_pid >/dev/null 2>&1; then
                echo "✅ $browser lancé (PID: $browser_pid)"
                echo ""
                echo "╚════════════════════════════════════════════════════════════════╝"
                return 0
            fi
        fi
    done
    
    # Priorité 3: Python webbrowser
    if command -v python3 >/dev/null 2>&1; then
        echo "🚀 Tentative avec Python webbrowser..."
        python3 -c "import webbrowser; webbrowser.open('file://$abs_path')" 2>/dev/null &
        sleep 2
        echo "✅ Commande Python exécutée"
        echo ""
        echo "╚════════════════════════════════════════════════════════════════╝"
        return 0
    fi
    
    # Si tout échoue
    echo ""
    echo "⚠️  OUVERTURE AUTOMATIQUE IMPOSSIBLE"
    echo ""
    echo "💡 Ouvrez manuellement dans votre navigateur:"
    echo ""
    echo "   file://$abs_path"
    echo ""
    echo "   Ou copiez-collez cette commande:"
    echo "   xdg-open \"$abs_path\""
    echo ""
    echo "╚════════════════════════════════════════════════════════════════╝"
    
    return 1
}

# Fonction pour installer le daemon de notification manquant
install_notification_daemon() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  📦 INSTALLATION DU DAEMON DE NOTIFICATION                     ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Détecter l'environnement de bureau
    local desktop="${XDG_CURRENT_DESKTOP:-unknown}"
    local daemon=""
    
    case "$desktop" in
        *GNOME*)
            daemon="notify-osd"
            echo "🖥️  Environnement GNOME détecté"
            ;;
        *KDE*|*Plasma*)
            daemon="plasma-workspace"
            echo "🖥️  Environnement KDE détecté"
            ;;
        *XFCE*)
            daemon="xfce4-notifyd"
            echo "🖥️  Environnement XFCE détecté"
            ;;
        *)
            daemon="notification-daemon"
            echo "🖥️  Environnement de bureau inconnu, utilisation de notification-daemon"
            ;;
    esac
    
    echo "📦 Daemon recommandé: $daemon"
    echo ""
    read -p "Voulez-vous installer $daemon maintenant ? (o/n): " response
    
    if [[ "$response" =~ ^[Oo]$ ]]; then
        echo "📥 Installation en cours..."
        sudo apt-get update && sudo apt-get install -y "$daemon"
        
        if [ $? -eq 0 ]; then
            echo ""
            echo "✅ Installation réussie !"
            echo "⚠️  Vous devrez peut-être redémarrer votre session pour que les notifications fonctionnent"
            echo ""
            read -p "Voulez-vous redémarrer votre session maintenant ? (o/n): " restart
            if [[ "$restart" =~ ^[Oo]$ ]]; then
                echo "🔄 Déconnexion en cours..."
                gnome-session-quit --logout --no-prompt 2>/dev/null || \
                xfce4-session-logout --logout 2>/dev/null || \
                qdbus org.kde.ksmserver /KSMServer logout 0 0 0 2>/dev/null || \
                echo "❌ Impossible de déconnecter automatiquement. Déconnectez-vous manuellement."
            fi
        else
            echo "❌ Échec de l'installation"
        fi
    else
        echo "⏭️  Installation ignorée"
    fi
    
    echo ""
}

# Test rapide des fonctions
test_functions() {
    echo "🧪 Test des fonctions de notification et ouverture HTML"
    echo ""
    
    # Test notifications
    echo "1️⃣  Test notification normale..."
    send_desktop_notification "Test Normal" "Ceci est une notification normale" "normal"
    sleep 3
    
    echo ""
    echo "2️⃣  Test notification critique..."
    send_desktop_notification "Test Critique" "Ceci est une notification CRITIQUE" "critical"
    sleep 3
    
    echo ""
    echo "3️⃣  Test notification discrète..."
    send_desktop_notification "Test Discret" "Ceci est une notification discrète" "low"
    sleep 3
    
    # Test ouverture HTML
    echo ""
    echo "4️⃣  Test d'ouverture HTML..."
    test_html="/tmp/test_notification_$(date +%s).html"
    cat > "$test_html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Test Réussi</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .card {
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 500px;
        }
        .emoji { font-size: 80px; margin: 0; }
        h1 { color: #667eea; margin: 20px 0 10px; }
        p { color: #666; font-size: 18px; }
        .time { color: #999; font-size: 14px; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="card">
        <div class="emoji">✅</div>
        <h1>Test Réussi !</h1>
        <p><strong>Le navigateur s'est ouvert correctement</strong></p>
        <p>Les fonctions de notification et d'ouverture HTML fonctionnent.</p>
        <div class="time">Généré le <span id="time"></span></div>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString('fr-FR');
    </script>
</body>
</html>
EOF
    
    open_html_report "$test_html"
    
    echo ""
    echo "✅ Test terminé"
    echo "💡 Si les notifications n'apparaissent pas, installez le daemon:"
    echo "   sudo apt-get install notification-daemon"
    
    # Attendre avant de nettoyer
    sleep 5
    rm -f "$test_html"
}

# Si le script est exécuté directement
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-}" in
        --test)
            test_functions
            ;;
        --install-daemon)
            install_notification_daemon
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --test              Tester les fonctions"
            echo "  --install-daemon    Installer le daemon de notification"
            echo "  --help, -h          Afficher cette aide"
            echo ""
            echo "Ou sourcez ce fichier dans votre script:"
            echo "  source $0"
            ;;
        *)
            echo "✅ Fonctions chargées avec succès"
            echo "💡 Utilisez --help pour voir les options"
            ;;
    esac
fi
# Fonction de diagnostic de l'environnement
diagnose_environment() {
    echo "🔍 ════════════════════════════════════════"
    echo "🔍 DIAGNOSTIC DE L'ENVIRONNEMENT"
    echo "🔍 ════════════════════════════════════════"
    echo ""
    
    echo "📺 Environnement graphique:"
    echo "   DISPLAY: ${DISPLAY:-non défini}"
    echo "   USER: ${USER:-non défini}"
    echo "   HOME: ${HOME:-non défini}"
    echo "   XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-non défini}"
    echo ""
    
    echo "🔔 Outils de notification disponibles:"
    for tool in notify-send zenity kdialog osascript; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "   ✅ $tool"
        else
            echo "   ❌ $tool (non installé)"
        fi
    done
    echo ""
    
    echo "🌐 Navigateurs disponibles:"
    local found_browser=false
    for browser in firefox google-chrome chromium chromium-browser brave-browser; do
        if command -v "$browser" >/dev/null 2>&1; then
            local version=$($browser --version 2>/dev/null | head -1)
            echo "   ✅ $browser: $version"
            found_browser=true
        fi
    done
    
    if [ "$found_browser" = false ]; then
        echo "   ❌ Aucun navigateur trouvé"
        echo ""
        echo "💡 Pour installer un navigateur:"
        echo "   sudo apt-get install firefox"
        echo "   sudo apt-get install chromium-browser"
    fi
    echo ""
    
    echo "🔧 Outils système:"
    for tool in xdg-open python3; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "   ✅ $tool"
        else
            echo "   ❌ $tool (non installé)"
        fi
    done
    echo ""
    
    echo "🖥️  Processus X11:"
    if ps aux | grep -v grep | grep -q "X\|Xorg"; then
        echo "   ✅ Serveur X actif"
        ps aux | grep -E "X[org]*" | grep -v grep | head -3
    else
        echo "   ❌ Aucun serveur X détecté"
    fi
    echo ""
    
    echo "════════════════════════════════════════"
}

# Test interactif des fonctions
test_notifications_and_browser() {
    local test_html="/tmp/test_notification_$(date +%s).html"
    
    echo "🧪 ════════════════════════════════════════"
    echo "🧪 TEST DES NOTIFICATIONS ET NAVIGATEUR"
    echo "🧪 ════════════════════════════════════════"
    echo ""
    
    # Diagnostic
    diagnose_environment
    
    echo "📝 Création d'un fichier HTML de test..."
    cat > "$test_html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Test de Notification</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .success {
            background: white;
            color: #333;
            padding: 30px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
        }
        h1 { color: #667eea; }
        .emoji { font-size: 60px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="success">
        <div class="emoji">✅</div>
        <h1>Test Réussi!</h1>
        <p><strong>Le navigateur a été ouvert avec succès.</strong></p>
        <p>Temps: <span id="time"></span></p>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF
    echo "✅ Fichier créé: $test_html"
    echo ""
    
    # Test de notification
    echo "🔔 Test de notification..."
    send_desktop_notification "Test de Notification" "Si vous voyez ceci, les notifications fonctionnent!" "normal"
    echo ""
    sleep 2
    
    # Test d'ouverture du navigateur
    echo "🌐 Test d'ouverture du navigateur..."
    open_html_report "$test_html"
    echo ""
    
    echo "⏳ Attente de 10 secondes pour observer les résultats..."
    sleep 10
    
    # Nettoyage
    rm -f "$test_html"
    
    echo ""
    echo "🧪 Test terminé!"
    echo "════════════════════════════════════════"
}

# Afficher l'aide
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat << 'HELP'
Usage: source ce_script.sh [--test]

Options:
  --test              Lancer un test complet des notifications et navigateur
  --diagnose          Afficher le diagnostic de l'environnement
  --help, -h          Afficher cette aide

Fonctions disponibles:
  send_desktop_notification "Titre" "Message" [urgency]
  open_html_report "/chemin/vers/fichier.html"
  diagnose_environment
  test_notifications_and_browser

Exemple d'utilisation:
  source ce_script.sh
  send_desktop_notification "Mon Titre" "Mon message" "critical"
  open_html_report "$HOME/rapport.html"

HELP
    exit 0
fi

# Si appelé avec --test
if [ "${1:-}" = "--test" ]; then
    test_notifications_and_browser
    exit 0
fi

# Si appelé avec --diagnose
if [ "${1:-}" = "--diagnose" ]; then
    diagnose_environment
    exit 0
fi

echo "✅ Fonctions de notification et ouverture HTML chargées"
echo "💡 Utilisez --help pour voir les options disponibles"



# Fonction pour créer le rapport HTML avec classement par mots-clés
create_html_report() {
    local changed_urls=()
    local unchanged_urls=()
    
    # Structures pour le classement par mots-clés
    declare -A keywords_categories
    declare -A keywords_descriptions
    local other_changes=()
    
    echo "📊 Génération du rapport HTML avec classement par mots-clés..."
    
    # Initialiser les catégories de mots-clés
    if [ -f "$KEYWORDS_FILE" ]; then
        while IFS='|' read -r keyword description || [ -n "$keyword" ]; do
            if [[ -n "$keyword" && "$keyword" != \#* ]]; then
                keywords_categories["$keyword"]=""
                keywords_descriptions["$keyword"]="$description"
            fi
        done < "$KEYWORDS_FILE"
    fi
    
    # Analyser les URLs pour détecter les changements et les classer
    while IFS= read -r URL || [ -n "$URL" ]; do
        if [[ -n "$URL" && "$URL" != \#* ]]; then
            local URL_HASH=$(echo "$URL" | md5sum | cut -d' ' -f1)
            local URL_DIR="$BASE_DIR/snapshots/$URL_HASH"
            local CURRENT_TEXT="$URL_DIR/current_text.txt"
            local PREVIOUS_TEXT="$URL_DIR/previous_text.txt"
            
            if [ -f "$CURRENT_TEXT" ] && [ -f "$PREVIOUS_TEXT" ]; then
                local CURRENT_HASH=$(get_content_hash "$CURRENT_TEXT")
                local PREVIOUS_HASH=$(get_content_hash "$PREVIOUS_TEXT")
                
                if [ "$CURRENT_HASH" != "$PREVIOUS_HASH" ]; then
                    changed_urls+=("$URL")
                    CHANGES_DETECTED=true
                    
                    # Vérifier si des mots-clés ont été trouvés pour cette URL
                    local url_keywords=""
                    if [ -f "$KEYWORDS_RESULTS_FILE" ]; then
                        url_keywords=$(grep "^$URL_HASH|" "$KEYWORDS_RESULTS_FILE" | tail -1 | cut -d'|' -f4)
                    fi
                    
                    if [ -n "$url_keywords" ]; then
                        # Classer par mots-clés
		    local classified=false
                    
                    # Lire les mots-clés (maintenant séparés par des virgules)
                    IFS=',' read -r -a keywords_array <<< "$url_keywords"
                    
                    for keyword in "${keywords_array[@]}"; do
                        # Correction: Vérifier si la CLÉ existe, pas si la VALEUR est non-vide
                        if [[ -v keywords_categories["$keyword"] ]]; then
                                keywords_categories["$keyword"]+="$URL"$'\n'
                                classified=true
                                break  # Une URL peut appartenir à plusieurs catégories, mais on prend la première
                            fi
                        done
                        
                        if [ "$classified" = false ]; then
                            other_changes+=("$URL")
                        fi
                    else
                        # Aucun mot-clé trouvé
                        other_changes+=("$URL")
                    fi
                else
                    unchanged_urls+=("$URL")
                fi
            else
                unchanged_urls+=("$URL")
            fi
        fi
    done < "$URL_LIST_FILE"
    
    # Créer le fichier HTML avec classement par mots-clés
    cat > "$HTML_REPORT_FILE" << EOF
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport des Changements - Website Monitor</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }
        .section {
            margin-bottom: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
            border-left: 4px solid #3498db;
        }
        .keyword-section {
            margin-bottom: 20px;
            padding: 15px;
            background: white;
            border-radius: 6px;
            border: 1px solid #e9ecef;
        }
        .url-card {
            background: #f8f9fa;
            border: 1px solid #e9ecef;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 10px;
            transition: all 0.3s ease;
        }
        .url-card:hover {
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        .url-card.changed {
            border-left: 5px solid #e74c3c;
            background: #fff5f5;
        }
        .url-card.unchanged {
            border-left: 5px solid #27ae60;
            background: #f0fff4;
        }
        .url-link {
            color: #3498db;
            text-decoration: none;
            font-weight: bold;
            word-break: break-all;
        }
        .url-link:hover {
            text-decoration: underline;
            color: #2980b9;
        }
        .status {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 15px;
            font-size: 0.8em;
            font-weight: bold;
            margin-left: 10px;
        }
        .status.changed {
            background: #e74c3c;
            color: white;
        }
        .status.unchanged {
            background: #27ae60;
            color: white;
        }
        .header-info {
            background: #ecf0f1;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .count-badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 10px;
            background: #3498db;
            color: white;
            font-size: 0.8em;
            margin-left: 5px;
        }
        .keyword-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 15px;
            background: #9b59b6;
            color: white;
            font-size: 0.8em;
            margin-left: 10px;
            font-weight: bold;
        }
        .category-header {
            display: flex;
            align-items: center;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 2px solid #ecf0f1;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Rapport des Changements - Website Monitor</h1>
        
        <div class="header-info">
            <strong>Généré le:</strong> $(date '+%Y-%m-%d à %H:%M:%S')<br>
            <strong>Utilisateur:</strong> $(whoami)<br>
            <strong>Total d'URLs surveillées:</strong> <span class="count-badge">$((${#changed_urls[@]} + ${#unchanged_urls[@]}))</span><br>
            <strong>URLs modifiées:</strong> <span class="count-badge" style="background: #e74c3c">${#changed_urls[@]}</span><br>
            <strong>URLs inchangées:</strong> <span class="count-badge" style="background: #27ae60">${#unchanged_urls[@]}</span>
        </div>

EOF

    # Afficher les URLs classées par mots-clés
    local has_keyword_changes=false
    for keyword in "${!keywords_categories[@]}"; do
        local urls_list="${keywords_categories[$keyword]}"
        if [ -n "$urls_list" ]; then
            has_keyword_changes=true
            local description="${keywords_descriptions[$keyword]}"
            local url_count=$(echo "$urls_list" | grep -c '^http')
            
            cat >> "$HTML_REPORT_FILE" << EOF
        <div class="section">
            <div class="category-header">
                <h2>🏷️ $description</h2>
                <span class="keyword-badge">$keyword</span>
                <span class="count-badge" style="background: #9b59b6">$url_count</span>
            </div>
EOF

            while IFS= read -r url; do
                if [ -n "$url" ]; then
                    cat >> "$HTML_REPORT_FILE" << EOF
            <div class="url-card changed">
                <a href="$url" class="url-link" target="_blank">$url</a>
                <span class="status changed">MOT-CLÉ: $keyword</span>
            </div>
EOF
                fi
            done <<< "$urls_list"

            cat >> "$HTML_REPORT_FILE" << EOF
        </div>
EOF
        fi
    done

    # Afficher la section "Autres changements"
    if [ ${#other_changes[@]} -gt 0 ]; then
        cat >> "$HTML_REPORT_FILE" << EOF
        <div class="section">
            <div class="category-header">
                <h2>🔍 Autres Changements</h2>
                <span class="count-badge" style="background: #f39c12">${#other_changes[@]}</span>
            </div>
            <p style="color: #7f8c8d; font-style: italic; margin-bottom: 15px;">
                Changements ne correspondant à aucun mot-clé défini
            </p>
EOF

        for url in "${other_changes[@]}"; do
            cat >> "$HTML_REPORT_FILE" << EOF
            <div class="url-card changed">
                <a href="$url" class="url-link" target="_blank">$url</a>
                <span class="status changed">AUTRE CHANGEMENT</span>
            </div>
EOF
        done

        cat >> "$HTML_REPORT_FILE" << EOF
        </div>
EOF
    fi

    # Afficher un message si aucun changement avec mot-clé
    if [ "$has_keyword_changes" = false ] && [ ${#other_changes[@]} -eq 0 ] && [ ${#changed_urls[@]} -gt 0 ]; then
        cat >> "$HTML_REPORT_FILE" << EOF
        <div class="section">
            <h2>🚨 URLs avec Changements <span class="count-badge" style="background: #e74c3c">${#changed_urls[@]}</span></h2>
EOF

        for url in "${changed_urls[@]}"; do
            cat >> "$HTML_REPORT_FILE" << EOF
            <div class="url-card changed">
                <a href="$url" class="url-link" target="_blank">$url</a>
                <span class="status changed">CHANGEMENT</span>
            </div>
EOF
        done

        cat >> "$HTML_REPORT_FILE" << EOF
        </div>
EOF
    elif [ ${#changed_urls[@]} -eq 0 ]; then
        cat >> "$HTML_REPORT_FILE" << EOF
        <div class="section">
            <h2>✅ Aucun Changement Détecté</h2>
            <p style="color: #7f8c8d; font-style: italic;">Toutes les URLs surveillées sont inchangées.</p>
        </div>
EOF
    fi

    # Section des URLs inchangées
    cat >> "$HTML_REPORT_FILE" << EOF
        <div class="section">
            <h2>✅ URLs Inchangées <span class="count-badge" style="background: #27ae60">${#unchanged_urls[@]}</span></h2>
EOF

    if [ ${#unchanged_urls[@]} -gt 0 ]; then
        for url in "${unchanged_urls[@]}"; do
            cat >> "$HTML_REPORT_FILE" << EOF
            <div class="url-card unchanged">
                <a href="$url" class="url-link" target="_blank">$url</a>
                <span class="status unchanged">OK</span>
            </div>
EOF
        done
    else
        cat >> "$HTML_REPORT_FILE" << EOF
            <p style="color: #7f8c8d; font-style: italic;">Aucune URL inchangée</p>
EOF
    fi

    cat >> "$HTML_REPORT_FILE" << EOF
        </div>
    </div>
    
    <script>
        // Auto-refresh toutes les 5 minutes
        setTimeout(function() {
            location.reload();
        }, 300000);
        
        // Ouvrir les liens dans un nouvel onglet
        document.addEventListener('DOMContentLoaded', function() {
            const links = document.querySelectorAll('.url-link');
            links.forEach(link => {
                link.setAttribute('target', '_blank');
            });
        });
    </script>
</body>
</html>
EOF

    echo "✅ Rapport HTML avec classement par mots-clés généré: $HTML_REPORT_FILE"
    
    # Nettoyer le fichier de résultats des mots-clés pour la prochaine exécution
    if [ -f "$KEYWORDS_RESULTS_FILE" ]; then
        rm -f "$KEYWORDS_RESULTS_FILE"
    fi
    
    # Mettre à jour la variable globale
    if [ ${#changed_urls[@]} -gt 0 ]; then
        ANY_CHANGE_DETECTED=true
        return 0  # Changements détectés
    else
        ANY_CHANGE_DETECTED=false
        return 1  # Aucun changement
    fi
}



# =============================================================================
# FONCTION DE MISE A JOUR DES RÉFÉRENCES
# =============================================================================
update_baselines() {
    echo "🔄 Mise à jour des fichiers de référence (baselines)..."
    while IFS= read -r URL || [ -n "$URL" ]; do
        if [[ -n "$URL" && "$URL" != \#* ]]; then
            local URL_HASH=$(echo "$URL" | md5sum | cut -d' ' -f1)
            local URL_DIR="$BASE_DIR/snapshots/$URL_HASH"
            local CURRENT_TEXT="$URL_DIR/current_text.txt"
            local PREVIOUS_TEXT="$URL_DIR/previous_text.txt"
            
            if [ -f "$CURRENT_TEXT" ]; then
                # C'est ici qu'on met à jour la référence pour la PROCHAINE exécution
                cp -f "$CURRENT_TEXT" "$PREVIOUS_TEXT"
            fi
        fi
    done < "$URL_LIST_FILE"
    echo "✅ Références mises à jour."
}


# =============================================================================
# FONCTIONS EXISTANTES (avec modifications mineures)
# =============================================================================

# Vérifier et installer les dépendances
check_dependencies() {
    local missing_deps=()
    
    echo "🔍 Vérification des dépendances..."
    
    # Vérifier html2text
    if ! command -v html2text >/dev/null 2>&1; then
        echo "⚠️  html2text n'est pas installé"
        missing_deps+=("html2text")
    else
        echo "✅ html2text installé"
    fi

    # Vérifier Node.js et Puppeteer si activé
    if [ "$ENABLE_PUPPETEER" = true ]; then
        if ! command -v node >/dev/null 2>&1; then
            echo "❌ Node.js n'est pas installé. Puppeteer ne pourra pas fonctionner."
            missing_deps+=("nodejs")
        else
            local node_version=$(node --version)
            echo "✅ Node.js installé: $node_version"
        fi
        
        # Vérifier si Puppeteer est installé DANS LE PROJET
        if [ ! -d "$PUPPETEER_MODULE_DIR/node_modules/puppeteer" ]; then
            echo "📦 Puppeteer n'est pas installé dans $PUPPETEER_MODULE_DIR"
            echo "💡 Exécutez ./scripts/install.sh pour l'installer."
        else
            echo "✅ Puppeteer déjà installé dans le projet"
        fi
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        echo "❌ Dépendances manquantes: ${missing_deps[*]}"
        echo ""
        echo "📦 Installation automatique..."
        echo ""
        
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "html2text")
                    if command -v apt-get >/dev/null 2>&1; then
                        sudo apt-get update && sudo apt-get install -y html2text
                    elif command -v yum >/dev/null 2>&1; then
                        sudo yum install -y html2text
                    elif command -v brew >/dev/null 2>&1; then
                        brew install html2text
                    fi
                    ;;
                "nodejs")
                    echo "Pour installer Node.js:"
                    echo "  Ubuntu/Debian: sudo apt-get install -y nodejs npm"
                    echo "  macOS: brew install node"
                    echo "  Ou visitez: https://nodejs.org/"
                    return 1
                    ;;
            esac
        done
    fi
    
    echo ""
    return 0
}


# Exécuter Puppeteer avec meilleure gestion d'erreurs
run_puppeteer() {
    local url="$1"
    local output_file="$2"
    
    if [ ! -f "$PUPPETEER_SCRIPT" ]; then
        echo "❌ Script Puppeteer non trouvé"
        return 1
    fi
    
    # Utiliser le module local
    cd "$PUPPETEER_MODULE_DIR" 2>/dev/null || cd "$PROJECT_ROOT"
    
    # Créer un fichier temporaire pour les logs
    local log_file=$(mktemp)
    
    echo "🤖 Exécution de Puppeteer..."
    
    # Exécuter avec timeout et capturer les erreurs
    timeout 120 node "$PUPPETEER_SCRIPT" "$url" "$output_file" 2>"$log_file"
    local exit_code=$?
    
    # Afficher les logs
    if [ -s "$log_file" ]; then
        cat "$log_file" | while IFS= read -r line; do
            echo "   $line"
        done
    fi
    
    rm -f "$log_file"
    
    # Vérifier le résultat
    if [ $exit_code -eq 124 ]; then
        echo "❌ Puppeteer: timeout (>120s)"
        return 1
    elif [ $exit_code -ne 0 ]; then
        echo "❌ Puppeteer a échoué avec le code: $exit_code"
        return 1
    fi
    
    if [ -s "$output_file" ]; then
        local size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
        echo "✅ Fichier créé: $size bytes"
        return 0
    else
        echo "❌ Fichier de sortie vide"
        rm -f "$output_file"
        return 1
    fi
}

# Fonction pour télécharger une page avec fallback amélioré
download_page() {
    local url="$1"
    local output_file="$2"
    local url_hash="$3"
    
    # Charger la configuration pour cette URL
    load_zone_config "$url_hash"
    
    # Déterminer s’il faut Puppeteer pour ce site
    local use_puppeteer=false
    if [ "$ENABLE_PUPPETEER" = true ] || [ "$FORCE_PUPPETEER" = "true" ]; then
        use_puppeteer=true
    fi
    
    local need_puppeteer=false
    if [[ "$url" =~ (react|angular|vue|svelte|nextjs|nuxtjs|\.app\.|localhost:|3000|4200|8080) ]] || [ "$FORCE_PUPPETEER" = "true" ]; then
        need_puppeteer=true
        echo "🔧 Site JavaScript détecté ou Puppeteer forcé, utilisation de Puppeteer"
    fi

    echo "🌐 Téléchargement de: $url"
    
    # Essayer d'abord avec cURL pour les sites simples
    if [ "$need_puppeteer" = false ] && [ "$use_puppeteer" = true ]; then
        echo "🔄 Test avec cURL en premier..."
        if curl $CURL_OPTIONS "$url" -o "$output_file.curl" 2>/dev/null && [ -s "$output_file.curl" ]; then
            # Analyser le contenu pour détecter les SPA
            if grep -q -E "<script[^>]*src|React|Angular|Vue\.|window\.|document\.|DOMContentLoaded|className|ng-|v-bind" "$output_file.curl"; then
                echo "⚠️  Framework JavaScript détecté dans le contenu, basculement vers Puppeteer"
                need_puppeteer=true
                rm -f "$output_file.curl"
            else
                echo "✅ Contenu statique valide avec cURL"
                mv "$output_file.curl" "$output_file"
                return 0
            fi
        else
            echo "❌ cURL a échoué ou page vide"
            rm -f "$output_file.curl"
            need_puppeteer=true
        fi
    fi
    
    # Utiliser Puppeteer si nécessaire
    if [ "$need_puppeteer" = true ] && [ "$use_puppeteer" = true ]; then
        echo "🌐 Utilisation de Puppeteer pour le rendu JavaScript..."
        if run_puppeteer "$url" "$output_file"; then
            # Vérifier que le contenu n'est pas vide
            if [ -s "$output_file" ]; then
                local content_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
                echo "✅ Puppeteer a récupéré $content_size bytes"
                return 0
            else
                echo "❌ Puppeteer a retourné un fichier vide"
                rm -f "$output_file"
                return 1
            fi
        else
            echo "❌ Puppeteer a échoué"
            return 1
        fi
    fi
    
    # Fallback final avec cURL
    echo "🔄 Tentative finale avec cURL..."
    if curl $CURL_OPTIONS "$url" -o "$output_file" 2>/dev/null && [ -s "$output_file" ]; then
        echo "✅ Récupération avec cURL (fallback)"
        return 0
    else
        echo "❌ Toutes les méthodes ont échoué"
        rm -f "$output_file"
        return 1
    fi
}

# Fonction de diagnostic
diagnose_url() {
    local url="$1"
    local url_hash=$(echo "$url" | md5sum | cut -d' ' -f1)
    local test_dir="$BASE_DIR/diagnostic/$url_hash"
    
    mkdir -p "$test_dir"
    
    echo "🔍 Diagnostic de: $url"
    echo "📁 Dossier: $test_dir"
    echo ""
    
    # Test cURL
    echo "1. 📡 Test cURL..."
    if curl $CURL_OPTIONS "$url" -o "$test_dir/curl_output.html" 2>"$test_dir/curl_error.log"; then
        local curl_size=$(stat -c%s "$test_dir/curl_output.html" 2>/dev/null || stat -f%z "$test_dir/curl_output.html" 2>/dev/null)
        echo "   ✅ Taille: $curl_size bytes"
        echo "   📊 Lignes: $(wc -l < "$test_dir/curl_output.html")"
        echo "   📝 Mots: $(wc -w < "$test_dir/curl_output.html")"
    else
        echo "   ❌ Échec du téléchargement cURL"
        if [ -s "$test_dir/curl_error.log" ]; then
            echo "   Erreur: $(cat "$test_dir/curl_error.log")"
        fi
    fi
    
    # Test Puppeteer
    if [ "$ENABLE_PUPPETEER" = true ]; then
        echo ""
        echo "2. 🤖 Test Puppeteer..."
        
        # S'assurer que Puppeteer est installé
        if [ ! -d "$BASE_DIR/puppeteer_module/node_modules/puppeteer" ]; then
            echo "   📦 Installation de Puppeteer..."
            create_puppeteer_script
        fi
        
        if run_puppeteer "$url" "$test_dir/puppeteer_output.html"; then
            local puppeteer_size=$(stat -c%s "$test_dir/puppeteer_output.html" 2>/dev/null || stat -f%z "$test_dir/puppeteer_output.html" 2>/dev/null)
            echo "   ✅ Taille: $puppeteer_size bytes"
            echo "   📊 Lignes: $(wc -l < "$test_dir/puppeteer_output.html")"
            echo "   📝 Mots: $(wc -w < "$test_dir/puppeteer_output.html")"
        else
            echo "   ❌ Échec du téléchargement Puppeteer"
        fi
    else
        echo "   ⚠️  Puppeteer désactivé"
    fi
    
    # Analyse du contenu
    echo ""
    echo "3. 🔍 Analyse du contenu..."
    if [ -f "$test_dir/curl_output.html" ]; then
        if grep -q -E "React|Angular|Vue\.|window\.__INITIAL|__NUXT__" "$test_dir/curl_output.html"; then
            echo "   ⚠️  Framework JavaScript détecté dans cURL"
        fi
        if grep -q "<script" "$test_dir/curl_output.html"; then
            local script_count=$(grep -c "<script" "$test_dir/curl_output.html")
            echo "   📜 $script_count balises <script> trouvées"
        fi
    fi
    
    # Comparaison
    echo ""
    echo "4. 📈 Comparaison des méthodes:"
    if [ -f "$test_dir/curl_output.html" ] && [ -f "$test_dir/puppeteer_output.html" ]; then
        local curl_words=$(wc -w < "$test_dir/curl_output.html")
        local puppeteer_words=$(wc -w < "$test_dir/puppeteer_output.html")
        
        echo "   cURL:      $curl_words mots"
        echo "   Puppeteer: $puppeteer_words mots"
        
        if [ $puppeteer_words -gt $((curl_words * 2)) ]; then
            echo "   ✅ Puppeteer a récupéré BEAUCOUP plus de contenu"
            echo "   💡 Recommandation: Utiliser FORCE_PUPPETEER=true dans zone_config.conf"
        elif [ $puppeteer_words -gt $curl_words ]; then
            echo "   ✅ Puppeteer a récupéré plus de contenu"
            echo "   💡 Recommandation: Utiliser FORCE_PUPPETEER=true dans zone_config.conf"
        else
            echo "   ⚠️  cURL suffit pour ce site"
        fi
    fi
    
    echo ""
    echo "✅ Diagnostic complet dans: $test_dir"
    echo "📁 Fichiers créés:"
    ls -lh "$test_dir/" 2>/dev/null
}

# Fonction pour envoyer des alertes Telegram
send_telegram_alert() {
    local message="$1"
    local url="$2"
    
    if [ "$ENABLE_TELEGRAM_ALERTS" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        local formatted_message="🚨 *Page Modifiée* 🚨

*URL:* \`$url\`
*Date:* $(date '+%Y-%m-%d %H:%M:%S')

$message"

        local encoded_message=$(echo "$formatted_message" | sed 's/ /%20/g; s/"/%22/g; s/\\/%5C/g; s/&/%26/g; s/+/%2B/g; s/|/%7C/g')
        
        curl -s -X POST \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${encoded_message}" \
            -d "parse_mode=Markdown" \
            -d "disable_web_page_preview=true" > /dev/null 2>&1 &
    fi
}

# Fonction pour logger les messages
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# =============================================================================
# FONCTIONS DE NETTOYAGE ET EXTRACTION
# =============================================================================

extract_text_with_html2text() {
    local input_file="$1"
    local output_file="$2"
    
    html2text -style pretty -utf8 -nometa -width 999 "$input_file" | \
    sed -E '
        s/[[:space:]]+/ /g # remplace les séquences de blancs (espaces, tabulations) multiples par un seul espace.
        s/^[[:space:]]+// # supprime les espaces en début de ligne.
        s/[[:space:]]+$// # supprime les espaces en fin de ligne.
       /^$/d  # supprime toutes les lignes vides.
    ' > "$output_file"
}

extract_text_fallback() {
    local input_file="$1"
    local output_file="$2"
    
    if command -v lynx >/dev/null 2>&1; then
        lynx -dump -nolist "$input_file" > "$output_file" 2>/dev/null
    else
        sed -E '
            s/<[^>]*>//g
            s/&[^;]*;//g
            s/[[:space:]]+/ /g
            /^[[:space:]]*$/d
        ' "$input_file" > "$output_file"
    fi
}

extract_between_markers() {
    local input_file="$1"
    local output_file="$2"
    local start_marker="$3"
    local end_marker="$4"
    
    awk -v start="$start_marker" -v end="$end_marker" '
        $0 ~ start { found=1 }
        found { print }
        $0 ~ end { found=0; exit }
    ' "$input_file" > "$output_file"
    
    if [ ! -s "$output_file" ]; then
        cp "$input_file" "$output_file"
        echo "⚠️  Marqueurs non trouvés: '$start_marker' -> '$end_marker'" >&2
    fi
}

remove_before_marker() {
    local input_file="$1"
    local output_file="$2"
    local marker="$3"
    
    sed -n "/$marker/,\$p" "$input_file" > "$output_file"
    
    if [ ! -s "$output_file" ]; then
        cp "$input_file" "$output_file"
        echo "⚠️  Marqueur de début non trouvé: '$marker'" >&2
    fi
}

remove_after_marker() {
    local input_file="$1"
    local output_file="$2"
    local marker="$3"
    
    sed -n "1,/$marker/p" "$input_file" > "$output_file"
    
    if [ ! -s "$output_file" ]; then
        cp "$input_file" "$output_file"
        echo "⚠️  Marqueur de fin non trouvé: '$marker'" >&2
    fi
}

# Charger la configuration des zones
load_zone_config() {
    local url_hash="$1"
    local config_file="$BASE_DIR/snapshots/$url_hash/zone_config.conf"
    
    # Réinitialiser les variables
    ZONE_MODE="full"
    ZONE_START=""
    ZONE_END=""
    FORCE_PUPPETEER="false"
    
    if [ -f "$config_file" ]; then
        source "$config_file"
    fi
}

# Nettoyage avancé avec gestion des zones
advanced_zone_cleaning() {
    local input_file="$1"
    local output_file="$2"
    local url_hash="$3"
    
    local temp_file=$(mktemp)
    
    if command -v html2text >/dev/null 2>&1; then
        extract_text_with_html2text "$input_file" "$temp_file"
    else
        extract_text_fallback "$input_file" "$temp_file"
    fi
    
    load_zone_config "$url_hash"
    
    case "$ZONE_MODE" in
        "between")
            if [ -n "$ZONE_START" ] && [ -n "$ZONE_END" ]; then
                extract_between_markers "$temp_file" "$output_file" "$ZONE_START" "$ZONE_END"
            else
                cp "$temp_file" "$output_file"
            fi
            ;;
        "before")
            if [ -n "$ZONE_START" ]; then
                remove_before_marker "$temp_file" "$output_file" "$ZONE_START"
            else
                cp "$temp_file" "$output_file"
            fi
            ;;
        "after")
            if [ -n "$ZONE_END" ]; then
                remove_after_marker "$temp_file" "$output_file" "$ZONE_END"
            else
                cp "$temp_file" "$output_file"
            fi
            ;;
        *)
            cp "$temp_file" "$output_file"
            ;;
    esac
    
    local final_temp=$(mktemp)
    sed -E '
        /^.{0,5}$/d
        s/[[:space:]]+/ /g
        s/^[[:space:]]+//
        s/[[:space:]]+$//
        /^$/d
    ' "$output_file" > "$final_temp"
    
    mv "$final_temp" "$output_file"
    rm -f "$temp_file"
}

get_content_hash() {
    local file="$1"
    cat "$file" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | md5sum | cut -d' ' -f1
}

# Créer un fichier de configuration de zone par défaut
# Créer un fichier de configuration de zone par défaut (version détaillée)

create_default_zone_config() {
    local url_hash="$1"
    local url="$2"
    local config_file="$BASE_DIR/snapshots/$url_hash/zone_config.conf"

    if [ ! -f "$config_file" ]; then
        cp "$CONFIG_DIR/zone_config.conf.example" "$config_file"
        # Remplacer les placeholders
        sed -i "s|# URL:.*|# URL: $url|" "$config_file"
        sed -i "s|# Hash:.*|# Hash: $url_hash|" "$config_file"
        sed -i "/# =================/a# Créé le: $(date '+%Y-%m-%d %H:%M:%S')" "$config_file"
        echo "📝 Configuration de zone créée: $config_file"
    else

        echo "📝 Configuration créée: $config_file"
    else
        # Mettre à jour l'URL si elle a changé
        update_config_url "$config_file" "$url"
    fi
}

# Fonction pour mettre à jour l'URL dans la configuration
update_config_url() {
    local config_file="$1"
    local url="$2"
    
    if [ -f "$config_file" ]; then
        local current_url_line=$(grep "^# URL:" "$config_file" | head -1)
        local current_url=$(echo "$current_url_line" | cut -d' ' -f3-)
        
        if [ "$current_url" != "$url" ]; then
            echo "🔄 Mise à jour de l'URL dans la configuration: $current_url → $url"
            sed -i "s|^# URL:.*|# URL: $url|" "$config_file"
            # Ajouter une ligne de mise à jour
            if ! grep -q "# Dernière mise à jour:" "$config_file"; then
                sed -i "/^# Créé le:/a# Dernière mise à jour: $(date '+%Y-%m-%d %H:%M:%S')" "$config_file"
            else
                sed -i "s|^# Dernière mise à jour:.*|# Dernière mise à jour: $(date '+%Y-%m-%d %H:%M:%S')|" "$config_file"
            fi
        fi
    fi
}
# =============================================================================
# FONCTIONS DE RECHERCHE DE MOTS-CLÉS
# =============================================================================

# Fonction pour rechercher des mots-clés dans les différences
search_keywords_in_changes() {
    local url="$1"
    local diff_content="$2"
    local url_hash="$3"
    
    # Vérifier si le fichier de mots-clés existe
   if [ ! -f "$KEYWORDS_FILE" ]; then
    echo "📝 Fichier de mots-clés non trouvé. Copie de l'exemple..."
    mkdir -p "$BASE_DIR"
    cp "$CONFIG_DIR/keywords.txt.example" "$KEYWORDS_FILE"
    echo "✅ Fichier de mots-clés créé: $KEYWORDS_FILE"
 
        echo "✅ Fichier de mots-clés créé: $KEYWORDS_FILE"
        return 1
    fi
    
    # Lire les mots-clés
    local keywords=()
    local descriptions=()
    
    while IFS='|' read -r keyword description || [ -n "$keyword" ]; do
        if [[ -n "$keyword" && "$keyword" != \#* ]]; then
            keywords+=("$keyword")
            descriptions+=("$description")
        fi
    done < "$KEYWORDS_FILE"
    
    if [ ${#keywords[@]} -eq 0 ]; then
        echo "⚠️  Aucun mot-clé défini dans $KEYWORDS_FILE"
        return 1
    fi
    
    echo "🔍 Recherche de ${#keywords[@]} mots-clés dans les changements..."
    
    # Convertir le diff en minuscules pour une recherche insensible à la casse
    local diff_lower=$(echo "$diff_content" | tr '[:upper:]' '[:lower:]')
    local found_keywords=()
    local found_descriptions=()
    
    # Rechercher chaque mot-clé
    for i in "${!keywords[@]}"; do
        local keyword="${keywords[$i]}"
        local description="${descriptions[$i]}"
        local keyword_lower=$(echo "$keyword" | tr '[:upper:]' '[:lower:]')
        
        # Préparer le motif de recherche pour les expressions multiples
        local search_pattern=$(prepare_search_pattern "$keyword_lower")
        
        # Rechercher avec le motif préparé
        if echo "$diff_lower" | grep -q -E "$search_pattern"; then
            found_keywords+=("$keyword")
            found_descriptions+=("$description")
            echo "   ✅ Mot-clé trouvé: '$keyword' ($description)"
        fi
    done
    
    # Enregistrer les résultats
    if [ ${#found_keywords[@]} -gt 0 ]; then
    local result_line="$url_hash|$url|$(date '+%Y-%m-%d %H:%M:%S')|$(IFS=,; echo "${found_keywords[*]}")|$(IFS=,; 
    echo "${found_descriptions[*]}")"
        echo "$result_line" >> "$KEYWORDS_RESULTS_FILE"
        echo "📋 Résultats enregistrés: ${found_keywords[*]}"
        return 0
    else
        echo "   ℹ️  Aucun mot-clé trouvé"
        return 1
    fi
}

# Fonction pour préparer les motifs de recherche pour les expressions multiples
prepare_search_pattern() {
    local keyword="$1"
    
    # Si le mot-clé contient des espaces (expression multiple)
    if [[ "$keyword" == *" "* ]]; then
        # Échapper les caractères spéciaux pour regex
        local escaped_keyword=$(echo "$keyword" | sed 's/[][\.*^$()+?{|]/\\&/g')
        # Créer un motif qui permet des variations d'espaces et de ponctuation
        local pattern=$(echo "$escaped_keyword" | sed 's/ /[[:space:][:punct:]]+/g')
        echo "$pattern"
    else
        # Pour les mots uniques, utiliser les limites de mots
        echo "\\b${keyword}\\b"
    fi
}

# Fonction pour analyser les changements et extraire le contexte
analyze_changes_with_context() {
    local previous_file="$1"
    local current_file="$2"
    local diff_output="$3"
    
    # Extraire les lignes modifiées avec leur contexte
    local changes_context=$(echo "$diff_output" | \
        grep -E '^[-+][^-+]' | \
        head -20 | \
        sed 's/^/    /')
    
    # Limiter la longueur pour éviter les fichiers trop volumineux
    if [ ${#changes_context} -gt 1000 ]; then
        changes_context="${changes_context:0:1000}..."
    fi
    
    echo "$changes_context"
}



# =============================================================================
# FONCTION PRINCIPALE DE SURVEILLANCE
# =============================================================================
monitor_single_url() {
    local URL="$1"
    local URL_HASH=$(echo "$URL" | md5sum | cut -d' ' -f1)
    local URL_DIR="$BASE_DIR/snapshots/$URL_HASH"

    local CURRENT_RAW="$URL_DIR/current_raw.html"
    local CURRENT_TEXT="$URL_DIR/current_text.txt"
    local PREVIOUS_TEXT="$URL_DIR/previous_text.txt"
    local URL_LOG_FILE="$URL_DIR/change.log"

    mkdir -p "$URL_DIR"
    create_default_zone_config "$URL_HASH" "$URL"

    # Télécharger la page avec le système hybride
    if ! download_page "$URL" "$CURRENT_RAW" "$URL_HASH"; then
        log_message "ERREUR: Échec du téléchargement de $URL"
        send_telegram_alert "❌ *Erreur de téléchargement*" "$URL"
        return 1
    fi

    if [ ! -s "$CURRENT_RAW" ]; then
        log_message "ERREUR: Fichier vide pour $URL"
        send_telegram_alert "📭 *Page vide* reçue" "$URL"
        return 1
    fi

    # Appliquer le nettoyage avec gestion des zones
    advanced_zone_cleaning "$CURRENT_RAW" "$CURRENT_TEXT" "$URL_HASH"

    if [ ! -s "$CURRENT_TEXT" ]; then
        log_message "ERREUR: Extraction texte vide pour $URL"
        return 1
    fi

    if [ -f "$PREVIOUS_TEXT" ]; then
        local CURRENT_HASH=$(get_content_hash "$CURRENT_TEXT")
        local PREVIOUS_HASH=$(get_content_hash "$PREVIOUS_TEXT")
        
        if [ "$CURRENT_HASH" != "$PREVIOUS_HASH" ]; then
            local DIFF_OUTPUT=$(diff -u "$PREVIOUS_TEXT" "$CURRENT_TEXT")
            
            if [ -n "$DIFF_OUTPUT" ]; then
                local CHANGES_COUNT=$(echo "$DIFF_OUTPUT" | grep -E '^[-+][^-+]' | wc -l)
                local CHANGES_CONTEXT=$(analyze_changes_with_context "$PREVIOUS_TEXT" "$CURRENT_TEXT" "$DIFF_OUTPUT")
                
                log_message "CHANGEMENT: $URL ($CHANGES_COUNT modifications)"
                ANY_CHANGE_DETECTED=true
                
                echo "========================================" >> "$URL_LOG_FILE"
                echo "CHANGEMENT DETECTE: $(date)" >> "$URL_LOG_FILE"
                echo "URL: $URL" >> "$URL_LOG_FILE"
                echo "Nombre de modifications: $CHANGES_COUNT" >> "$URL_LOG_FILE"
                echo "Mode de nettoyage: $ZONE_MODE" >> "$URL_LOG_FILE"
                echo "Méthode: $( [ "$FORCE_PUPPETEER" = "true" ] && echo "Puppeteer" || echo "cURL/Puppeteer" )" >> "$URL_LOG_FILE"
                echo "========================================" >> "$URL_LOG_FILE"
                echo "$DIFF_OUTPUT" >> "$URL_LOG_FILE"
                echo "" >> "$URL_LOG_FILE"
                
                # RECHERCHE DE MOTS-CLÉS
                local KEYWORDS_FOUND=""
                if search_keywords_in_changes "$URL" "$DIFF_OUTPUT" "$URL_HASH"; then
                    KEYWORDS_FOUND="avec mots-clés"
                else
                    KEYWORDS_FOUND="sans mots-clés spécifiques"
                fi
                
                local TELEGRAM_MSG="*$CHANGES_COUNT modification(s)* détectée(s) - *$KEYWORDS_FOUND*
_Mode de nettoyage:_ \`$ZONE_MODE\`
_Méthode:_ \`$( [ "$FORCE_PUPPETEER" = "true" ] && echo "Puppeteer" || echo "cURL/Puppeteer" )\`

_Premières modifications:_
\`\`\`
$CHANGES_CONTEXT
\`\`\`"

                send_telegram_alert "$TELEGRAM_MSG" "$URL"
                echo "🚨 $URL : $CHANGES_COUNT modification(s) détectée(s) - $KEYWORDS_FOUND (Mode: $ZONE_MODE)"
                
                cp "$CURRENT_RAW" "$URL_DIR/$(date +%Y%m%d_%H%M%S)_raw.html"
                cp "$CURRENT_TEXT" "$URL_DIR/$(date +%Y%m%d_%H%M%S)_text.txt"
                
            else
                echo "✓ $URL : Aucun changement détecté (hash différent mais diff vide)"
            fi
        else
            echo "✓ $URL : Aucun changement détecté"
        fi
    else      
        log_message "INIT: Premier snapshot pour $URL (Mode: $ZONE_MODE)"
        echo "📝 Initialisation de la surveillance pour $URL (Mode: $ZONE_MODE)"
        
        send_telegram_alert "✅ *Surveillance initialisée* 
Mode: \`$ZONE_MODE\`
Méthode: \`$( [ "$FORCE_PUPPETEER" = "true" ] && echo "Puppeteer" || echo "cURL/Puppeteer" )\`
Fichier config: \`zone_config.conf\`" "$URL"
    fi

}

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

main() {
    echo "🔍 Démarrage de la surveillance de sites web..."
    echo "   Dossier: $BASE_DIR"
    echo "   Log: $LOG_FILE"
    echo "   Telegram: $ENABLE_TELEGRAM_ALERTS"
    echo "   Puppeteer: $ENABLE_PUPPETEER"
    echo ""
    
    # Test de l'environnement graphique
    echo "🔧 Test de l'environnement graphique..."
    if [ -n "$DISPLAY" ]; then
        echo "✅ Display détecté: $DISPLAY"
    else
        echo "⚠️  Aucun display détecté - les notifications graphiques peuvent ne pas fonctionner"
    fi
    echo ""
    
    if ! check_dependencies; then
        echo ""
        echo "❌ Veuillez installer les dépendances manquantes et relancer le script."
        exit 1
    fi
    
    log_message "=== Début de la surveillance ==="

   if [ ! -f "$URL_LIST_FILE" ]; then
    echo "❌ ERREUR: Fichier $URL_LIST_FILE introuvable."
    echo "📝 Copie de l'exemple..."
    mkdir -p "$BASE_DIR"
    cp "$CONFIG_DIR/url_list.txt.example" "$URL_LIST_FILE"
    echo "✅ Fichier exemple créé: $URL_LIST_FILE"

        echo "✅ Fichier exemple créé: $URL_LIST_FILE"
        echo "📝 Veuillez éditer ce fichier avec vos URLs et relancer le script."
        exit 1
    fi

    local URL_COUNT=$(grep -v '^#' "$URL_LIST_FILE" | grep -v '^$' | wc -l)
    echo "📊 Nombre d'URLs à surveiller: $URL_COUNT"
    echo ""

    if [ $URL_COUNT -eq 0 ]; then
        echo "⚠️  Aucune URL à surveiller dans $URL_LIST_FILE"
        echo "📝 Veuillez ajouter des URLs et relancer le script."
        exit 1
    fi

    local COUNTER=0
    while IFS= read -r LINE || [ -n "$LINE" ]; do
        if [[ -n "$LINE" && "$LINE" != \#* ]]; then
            COUNTER=$((COUNTER + 1))
            echo "[$COUNTER/$URL_COUNT] Surveillance de: $LINE"
            monitor_single_url "$LINE"
            echo ""
        fi
    done < "$URL_LIST_FILE"

 
    # Générer le rapport HTML et gérer les notifications
    echo "📊 Génération du rapport HTML..."
    
    # Réinitialiser les variables de suivi
    #CHANGES_DETECTED=false
    #ANY_CHANGE_DETECTED=false
    
    # Créer le rapport HTML et capturer le résultat
    if create_html_report; then
        echo "🚨 CHANGEMENTS DÉTECTÉS : Rapport HTML généré avec URLs modifiées"
        
        # Notification desktop pour changements détectés
        send_desktop_notification "Website Monitor ALERT" "Changements détectés sur des URLs surveillées" "critical"
        
    else
        echo "✅ AUCUN CHANGEMENT : Toutes les URLs sont inchangées"
        
        # Notification desktop pour aucun changement
        send_desktop_notification "Website Monitor" "Aucun changement détecté sur $URL_COUNT URLs" "low"
    fi
    
    # TOUJOURS ouvrir le rapport HTML (qu'il y ait des changements ou non)
    echo ""
    echo "🌐 Ouverture du rapport HTML..."
    sleep 1
    open_html_report "$HTML_REPORT_FILE"
    # Mettre à jour les références APRES la génération du rapport
    update_baselines
    log_message "=== Fin de la surveillance ==="
    echo ""
    echo "✅ Surveillance terminée à $(date '+%H:%M:%S')"
    echo "📊 Log principal: $LOG_FILE"
    echo "📄 Rapport HTML: $HTML_REPORT_FILE"
    
    if [ "$ENABLE_TELEGRAM_ALERTS" = true ] && [ $URL_COUNT -gt 0 ]; then
        local changed_count=0
        local total_count=0
        
        # Compter les URLs modifiées
        while IFS= read -r URL || [ -n "$URL" ]; do
            if [[ -n "$URL" && "$URL" != \#* ]]; then
                total_count=$((total_count + 1))
                local URL_HASH=$(echo "$URL" | md5sum | cut -d' ' -f1)
                local URL_DIR="$BASE_DIR/snapshots/$URL_HASH"
                local CURRENT_TEXT="$URL_DIR/current_text.txt"
                local PREVIOUS_TEXT="$URL_DIR/previous_text.txt"
                
                if [ -f "$CURRENT_TEXT" ] && [ -f "$PREVIOUS_TEXT" ]; then
                    local CURRENT_HASH=$(get_content_hash "$CURRENT_TEXT")
                    local PREVIOUS_HASH=$(get_content_hash "$PREVIOUS_TEXT")
                    if [ "$CURRENT_HASH" != "$PREVIOUS_HASH" ]; then
                        changed_count=$((changed_count + 1))
                    fi
                fi
            fi
        done < "$URL_LIST_FILE"
        
        local SUMMARY="✅ Surveillance terminée
📊 $total_count site(s) surveillé(s)
$(if [ $changed_count -gt 0 ]; then echo "🚨 Changements détectés: $changed_count URL(s)"; else echo "✅ Aucun changement détecté"; fi)
🌐 Méthode: $( [ "$ENABLE_PUPPETEER" = true ] && echo "Hybride (cURL+Puppeteer)" || echo "cURL" )
🕒 $(date '+%Y-%m-%d %H:%M:%S')"
        send_telegram_alert "$SUMMARY" "Résumé"
    fi
}
show_help() {
    cat << 'EOFHELP'
Usage: ./script.sh [OPTIONS]

Options:
  --help, -h          Afficher cette aide
  --diagnose URL      Diagnostiquer une URL spécifique
  --monitor           Lancer la surveillance normale (défaut)
  --list-urls         Afficher la liste des URLs surveillées
  --install-deps      Installer les dépendances système

Exemples:
  ./script.sh --monitor                      # Surveillance normale
  ./script.sh --diagnose https://example.com # Diagnostiquer une URL
  ./script.sh --list-urls                    # Lister les URLs

Configuration:
  - Fichier URLs: ~/website_monitor/test_url_list.txt
  - Configurations: ~/website_monitor/snapshots/<hash>/zone_config.conf
  - Logs globaux: ~/website_monitor/global_change.log
  - Logs par URL: ~/website_monitor/snapshots/<hash>/change.log

Modes de surveillance:
  - full: Surveille toute la page (défaut)
  - between: Surveille entre deux marqueurs
  - before: Surveille après un marqueur
  - after: Surveille avant un marqueur

Pour forcer Puppeteer sur un site JavaScript:
  1. Éditez le fichier zone_config.conf de l'URL
  2. Changez FORCE_PUPPETEER="false" en FORCE_PUPPETEER="true"
  3. Relancez la surveillance

Dépendances requises:
  - html2text (extraction de texte)
  - Node.js + npm (pour Puppeteer)
  - curl (téléchargement de pages)

Pour plus d'informations: https://github.com/puppeteer/puppeteer
EOFHELP
}

list_urls() {
    if [ ! -f "$URL_LIST_FILE" ]; then
        echo "❌ Fichier $URL_LIST_FILE introuvable"
        exit 1
    fi
    
    echo "📋 URLs surveillées:"
    echo "==================="
    local counter=1
    while IFS= read -r LINE || [ -n "$LINE" ]; do
        if [[ -n "$LINE" && "$LINE" != \#* ]]; then
            local url_hash=$(echo "$LINE" | md5sum | cut -d' ' -f1)
            echo "$counter. $LINE"
            echo "   📁 Hash: $url_hash"
            echo "   📂 Dossier: $BASE_DIR/snapshots/$url_hash/"
            if [ -f "$BASE_DIR/snapshots/$url_hash/zone_config.conf" ]; then
                echo "   ⚙️  Configuration: zone_config.conf"
                # Afficher l'URL depuis le fichier de config
                local config_url=$(grep "^# URL:" "$BASE_DIR/snapshots/$url_hash/zone_config.conf" 2>/dev/null | head -1 | cut -d' ' -f3-)
                if [ -n "$config_url" ]; then
                    echo "   🔗 URL config: $config_url"
                fi
                # Afficher le mode actuel
                if [ -f "$BASE_DIR/snapshots/$url_hash/zone_config.conf" ]; then
                    local mode=$(grep "^ZONE_MODE=" "$BASE_DIR/snapshots/$url_hash/zone_config.conf" | cut -d'"' -f2)
                    local force_pup=$(grep "^FORCE_PUPPETEER=" "$BASE_DIR/snapshots/$url_hash/zone_config.conf" | cut -d'"' -f2)
                    echo "   🔧 Mode: $mode | Puppeteer forcé: $force_pup"
                fi
            fi
            if [ -f "$BASE_DIR/snapshots/$url_hash/change.log" ]; then
                local changes=$(grep -c "CHANGEMENT DETECTE" "$BASE_DIR/snapshots/$url_hash/change.log" 2>/dev/null || echo "0")
                echo "   📊 Changements détectés: $changes"
            fi
            counter=$((counter + 1))
            echo ""
        fi
    done < "$URL_LIST_FILE"
}
install_system_deps() {
    echo "🔧 Installation des dépendances système..."
    echo ""
    
    if command -v apt-get >/dev/null 2>&1; then
        echo "📦 Système détecté: Debian/Ubuntu"
        echo "Installation de: html2text, nodejs, npm, dépendances Puppeteer..."
        sudo apt-get update
        sudo apt-get install -y \
            html2text \
            nodejs \
            npm \
            libnss3 \
            libatk1.0-0 \
            libatk-bridge2.0-0 \
            libcups2 \
            libdrm2 \
            libxkbcommon0 \
            libxcomposite1 \
            libxdamage1 \
            libxfixes3 \
            libxrandr2 \
            libgbm1 \
            libasound2 \
            libpango-1.0-0 \
            libcairo2 \
            libx11-xcb1
    elif command -v yum >/dev/null 2>&1; then
        echo "📦 Système détecté: Red Hat/CentOS"
        sudo yum install -y html2text nodejs npm
    elif command -v brew >/dev/null 2>&1; then
        echo "📦 Système détecté: macOS"
        brew install html2text node
    else
        echo "❌ Gestionnaire de paquets non reconnu"
        echo "Veuillez installer manuellement:"
        echo "  - html2text"
        echo "  - Node.js et npm"
        exit 1
    fi
    
    echo ""
    echo "✅ Dépendances système installées"
    echo "📦 Installation de Puppeteer..."
    create_puppeteer_script
    echo ""
    echo "✅ Installation terminée !"
}

# Fonction pour gérer les mots-clés
manage_keywords() {
    echo "🔑 Gestion des mots-clés"
    echo ""
    
    # Créer le fichier s'il n'existe pas
    if [ ! -f "$KEYWORDS_FILE" ]; then
        echo "📝 Création du fichier de mots-clés par défaut..."
        mkdir -p "$BASE_DIR"
        cat > "$KEYWORDS_FILE" << 'EOFKEYWORDS'
# Fichier de mots-clés pour classer les changements
# Format: mot_clé|description (une entrée par ligne)
# Les lignes commençant par # sont ignorées

recrutement|Offres de recrutement, emplois
education|Nouvelles éducatives, programmes
urgence|Annonces urgentes, alertes
directeur des études|Postes de direction pédagogique
professeur de français|Enseignement du français
contrat local|Recrutement en contrat local
offre d emploi|Annonces d'emploi
EOFKEYWORDS
        echo "✅ Fichier de mots-clés créé: $KEYWORDS_FILE"
    fi
    
    echo "📋 Mots-clés actuels:"
    echo "===================="
    local counter=1
    while IFS='|' read -r keyword description || [ -n "$keyword" ]; do
        if [[ -n "$keyword" && "$keyword" != \#* ]]; then
            echo "$counter. '$keyword': $description"
            counter=$((counter + 1))
        fi
    done < "$KEYWORDS_FILE"
    
    echo ""
    echo "💡 INFORMATIONS:"
    echo "   - Les mots-clés sont recherchés dans le CONTENU des pages modifiées"
    echo "   - Les expressions multiples sont acceptées: 'directeur des études'"
    echo "   - La recherche est insensible à la casse (majuscules/minuscules)"
    echo "   - Les variations d'espaces et de ponctuation sont prises en compte"
    echo ""
    
    echo "Options:"
    echo "1. Ajouter un mot-clé"
    echo "2. Supprimer un mot-clé" 
    echo "3. Modifier un mot-clé"
    echo "4. Tester un mot-clé sur une URL"
    echo "5. Voir les URLs surveillées"
    echo "6. Quitter"
    echo ""
    
    read -p "Choisissez une option (1-6): " choice
    
    case $choice in
        1)
            echo ""
            echo "➕ Ajout d'un nouveau mot-clé"
            echo "💡 Exemples:"
            echo "   - Mot simple: salaire"
            echo "   - Expression: directeur des études"
            read -p "Mot-clé: " new_keyword
            read -p "Description: " new_description
            if [[ -n "$new_keyword" && -n "$new_description" ]]; then
                echo "$new_keyword|$new_description" >> "$KEYWORDS_FILE"
                echo "✅ Mot-clé ajouté: '$new_keyword' - $new_description"
            else
                echo "❌ Le mot-clé et la description ne peuvent pas être vides"
            fi
            ;;
        2)
            echo ""
            echo "🗑️  Suppression d'un mot-clé"
            read -p "Numéro du mot-clé à supprimer: " del_num
            if [[ ! "$del_num" =~ ^[0-9]+$ ]]; then
                echo "❌ Numéro invalide"
                return 1
            fi
            
            local temp_file=$(mktemp)
            local current_num=1
            local deleted_keyword=""
            
            while IFS='|' read -r keyword description || [ -n "$keyword" ]; do
                if [[ -n "$keyword" && "$keyword" != \#* ]]; then
                    if [ $current_num -eq $del_num ]; then
                        deleted_keyword="$keyword"
                        echo "🗑️  Supprimé: $keyword - $description"
                    else
                        echo "$keyword|$description" >> "$temp_file"
                    fi
                    current_num=$((current_num + 1))
                else
                    # Garder les commentaires
                    echo "$keyword|$description" >> "$temp_file"
                fi
            done < "$KEYWORDS_FILE"
            
            if [ -n "$deleted_keyword" ]; then
                mv "$temp_file" "$KEYWORDS_FILE"
                echo "✅ Mot-clé supprimé: $deleted_keyword"
            else
                rm -f "$temp_file"
                echo "❌ Aucun mot-clé trouvé avec le numéro $del_num"
            fi
            ;;
        3)
            echo ""
            echo "✏️  Modification d'un mot-clé"
            read -p "Numéro du mot-clé à modifier: " mod_num
            if [[ ! "$mod_num" =~ ^[0-9]+$ ]]; then
                echo "❌ Numéro invalide"
                return 1
            fi
            
            read -p "Nouveau mot-clé: " new_keyword
            read -p "Nouvelle description: " new_description
            
            if [[ -z "$new_keyword" || -z "$new_description" ]]; then
                echo "❌ Le mot-clé et la description ne peuvent pas être vides"
                return 1
            fi
            
            local temp_file=$(mktemp)
            local current_num=1
            local modified=false
            
            while IFS='|' read -r keyword description || [ -n "$keyword" ]; do
                if [[ -n "$keyword" && "$keyword" != \#* ]]; then
                    if [ $current_num -eq $mod_num ]; then
                        echo "$new_keyword|$new_description" >> "$temp_file"
                        echo "✏️  Modifié: '$keyword' → '$new_keyword'"
                        echo "    '$description' → '$new_description'"
                        modified=true
                    else
                        echo "$keyword|$description" >> "$temp_file"
                    fi
                    current_num=$((current_num + 1))
                else
                    echo "$keyword|$description" >> "$temp_file"
                fi
            done < "$KEYWORDS_FILE"
            
            if [ "$modified" = true ]; then
                mv "$temp_file" "$KEYWORDS_FILE"
                echo "✅ Mot-clé modifié avec succès"
            else
                rm -f "$temp_file"
                echo "❌ Aucun mot-clé trouvé avec le numéro $mod_num"
            fi
            ;;
        4)
            echo ""
            echo "🧪 Test d'un mot-clé sur une URL"
            echo ""
            
            # Afficher et stocker les URLs disponibles
            if [ -f "$URL_LIST_FILE" ]; then
                echo "📋 URLs disponibles:"
                echo "==================="
                local url_counter=1
                local url_array=()
                
                while IFS= read -r url_line || [ -n "$url_line" ]; do
                    if [[ -n "$url_line" && "$url_line" != \#* ]]; then
                        echo "$url_counter. $url_line"
                        url_array[$url_counter]="$url_line"
                        url_counter=$((url_counter + 1))
                    fi
                done < "$URL_LIST_FILE"
                
                local total_urls=$((url_counter - 1))
                echo ""
                echo "💡 Vous pouvez entrer:"
                echo "   - Un numéro entre 1 et $total_urls"
                echo "   - Une URL complète"
                echo ""
            else
                echo "❌ Fichier d'URLs non trouvé: $URL_LIST_FILE"
                return 1
            fi
            
            read -p "URL ou numéro à tester: " test_input
            read -p "Mot-clé à tester: " test_keyword
            
            if [[ -z "$test_input" || -z "$test_keyword" ]]; then
                echo "❌ URL/numéro et mot-clé sont requis"
                return 1
            fi
            
            # Déterminer l'URL à tester
            local test_url=""
            if [[ "$test_input" =~ ^[0-9]+$ ]]; then
                # C'est un numéro
                if [ "$test_input" -ge 1 ] && [ "$test_input" -le "$total_urls" ]; then
                    test_url="${url_array[$test_input]}"
                    echo "✅ URL sélectionnée: $test_url"
                else
                    echo "❌ Numéro invalide. Doit être entre 1 et $total_urls"
                    return 1
                fi
            else
                # C'est une URL
                test_url="$test_input"
            fi
            
            echo ""
            echo "🔍 Test en cours..."
            echo "   URL: $test_url"
            echo "   Mot-clé: '$test_keyword'"
            echo ""
            
            # Vérifier si Puppeteer est nécessaire pour cette URL
            local url_hash=$(echo "$test_url" | md5sum | cut -d' ' -f1)
            local use_puppeteer=false
            
            # Charger la configuration de la zone si elle existe
            if [ -f "$BASE_DIR/snapshots/$url_hash/zone_config.conf" ]; then
                source "$BASE_DIR/snapshots/$url_hash/zone_config.conf"
                if [ "$FORCE_PUPPETEER" = "true" ]; then
                    use_puppeteer=true
                fi
            fi
            
            # Détecter automatiquement si Puppeteer est nécessaire
            if [[ "$test_url" =~ (react|angular|vue|svelte|nextjs|nuxtjs|\.app\.|localhost:|3000|4200|8080) ]]; then
                use_puppeteer=true
                echo "🌐 Site JavaScript détecté, utilisation de Puppeteer..."
            fi
            
            # Télécharger la page avec la méthode appropriée
            local temp_file=$(mktemp)
            echo "📥 Téléchargement de la page..."
            
local download_success=false
            
            # Correction: Appeler la fonction download_page existante
            # qui gère déjà la logique cURL/Puppeteer
            if download_page "$test_url" "$temp_file" "$url_hash"; then
                download_success=true
                echo "✅ Page téléchargée (Méthode auto-détectée par download_page)"
            fi
            
            if [ "$download_success" = true ]; then
            local file_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null)
                echo "📊 Taille de la page: $file_size bytes"
                
                # Extraire le texte
                local text_file=$(mktemp)
                echo "📝 Extraction du texte..."
                
                # Appliquer le nettoyage avec gestion des zones si la configuration existe
                if [ -f "$BASE_DIR/snapshots/$url_hash/zone_config.conf" ]; then
                    advanced_zone_cleaning "$temp_file" "$text_file" "$url_hash"
                    echo "🔧 Nettoyage de zone appliqué"
                else
                    # Nettoyage basique
                    if command -v html2text >/dev/null 2>&1; then
                        html2text -style pretty -utf8 -nometa -width 999 "$temp_file" > "$text_file"
                    else
                        sed 's/<[^>]*>//g' "$temp_file" > "$text_file"
                    fi
                fi
                
                local text_content=$(cat "$text_file")
                local text_lower=$(echo "$text_content" | tr '[:upper:]' '[:lower:]' | tr 'àáâãäåèéêëìíîïòóôõöùúûüÿ' 'aaaaaaeeeeiiiiooooouuuuyy')
                local test_keyword_lower=$(echo "$test_keyword" | tr '[:upper:]' '[:lower:]' | tr 'àáâãäåèéêëìíîïòóôõöùúûüÿ' 'aaaaaaeeeeiiiiooooouuuuyy')
                local test_pattern=$(prepare_search_pattern "$test_keyword_lower")
                
                echo ""
                echo "🔎 Recherche du motif: $test_pattern"
                echo ""
                
                # Compter les occurrences
                local occurrence_count=$(echo "$text_lower" | grep -o -E "$test_pattern" | wc -l)
                
                if [ $occurrence_count -gt 0 ]; then
                    echo "✅ SUCCÈS: Le mot-clé '$test_keyword' a été trouvé $occurrence_count fois"
                    echo ""
                    echo "📝 Contexte des occurrences:"
                    echo "============================"
                    
                    # Afficher le contexte de chaque occurrence
                    local line_number=1
                    local occurrences_shown=0
                    
                    while IFS= read -r line; do
                        if [ -n "$line" ]; then
                            local line_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]' | tr 'àáâãäåèéêëìíîïòóôõöùúûüÿ' 'aaaaaaeeeeiiiiooooouuuuyy')
                            if echo "$line_lower" | grep -q -E "$test_pattern"; then
                                # Mettre en évidence le mot-clé dans la ligne
                                local highlighted_line=$(echo "$line" | grep --color=always -E -i "$(echo "$test_keyword" | sed 's/ /|/g')" 2>/dev/null || echo "$line")
                                echo "$line_number: $highlighted_line"
                                echo "---"
                                occurrences_shown=$((occurrences_shown + 1))
                                
                                if [ $occurrences_shown -ge 5 ]; then
                                    break
                                fi
                            fi
                        fi
                        line_number=$((line_number + 1))
                    done < "$text_file"
                    
                    if [ $occurrence_count -gt 5 ]; then
                        echo "... et $(($occurrence_count - 5)) autres occurrences"
                    fi
                    
                    echo ""
                    echo "💡 Ce mot-clé sera DÉTECTÉ lors des changements"
                    
                else
                    echo "❌ Le mot-clé '$test_keyword' n'a pas été trouvé sur la page"
                    echo ""
                    echo "🔍 Analyse du contenu:"
                    echo "   - Lignes de texte: $(wc -l < "$text_file")"
                    echo "   - Mots: $(wc -w < "$text_file")"
                    echo "   - Caractères: $(wc -c < "$text_file")"
                    echo ""
                    echo "💡 Suggestions:"
                    echo "   - Vérifier l'orthographe (essayez: 'physique-chimie', 'physique et chimie')"
                    echo "   - Essayer une forme plus courte ('physique', 'chimie')"
                    echo "   - Vérifier que la page contient du texte (pas seulement des images/PDF)"
                    echo "   - Tester avec une autre URL de la liste"
                    
                    # Afficher un échantillon du contenu pour debug
                    echo ""
                    echo "📄 Extrait du contenu texte (premières 10 lignes):"
                    echo "----------------------------------------"
                    head -10 "$text_file" | sed 's/^/   | /'
                fi
                
                # Nettoyer les fichiers temporaires
                rm -f "$temp_file" "$text_file"
                
            else
                echo "❌ Impossible de télécharger l'URL"
                echo "   Vérifiez:"
                echo "   - La connexion internet"
                echo "   - Que l'URL est accessible: $test_url"
                echo "   - Que l'URL n'est pas protégée"
                echo "   - Que Puppeteer est configuré si nécessaire"
                
                if [ "$use_puppeteer" = true ] && [ "$ENABLE_PUPPETEER" = false ]; then
                    echo "   ⚠️  Puppeteer est requis mais désactivé (ENABLE_PUPPETEER=false)"
                fi
                
                rm -f "$temp_file"
            fi
            ;;
         5)
            echo ""
            echo "🌐 URLs surveillées:"
            echo "==================="
            if [ -f "$URL_LIST_FILE" ]; then
                grep -v '^#' "$URL_LIST_FILE" | grep -v '^$' | nl -w2 -s'. '
                echo ""
                echo "Total: $(grep -v '^#' "$URL_LIST_FILE" | grep -v '^$' | wc -l) URLs"
            else
                echo "❌ Fichier d'URLs non trouvé: $URL_LIST_FILE"
            fi
            ;;
        6)
            echo "✅ Retour au menu principal"
            ;;
        *)
            echo "❌ Option invalide"
            ;;
    esac
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..." wait
}



install_puppeteer_stealth() {
    echo "📦 Installation de puppeteer-extra et puppeteer-extra-plugin-stealth..."
    mkdir -p "$PUPPETEER_MODULE_DIR"
    cd "$PUPPETEER_MODULE_DIR" || exit 1
    
    if [ ! -f "package.json" ]; then
        npm init -y > /dev/null 2>&1
    fi
    
    # Installer puppeteer-extra et plugin stealth si non installés
    if ! npm list puppeteer-extra >/dev/null 2>&1; then
        npm install puppeteer-extra puppeteer-extra-plugin-stealth --save
        if [ $? -eq 0 ]; then
            echo "✅ Installation des plugins stealth terminée"
        else
            echo "❌ Échec de l'installation des plugins stealth"
            exit 1
        fi
    else
        echo "✅ Plugins stealth déjà installés"
    fi
}


case "${1:-}" in
    "--help"|"-h")
        show_help
        exit 0
        ;;
    "--diagnose")
        if [ -z "$2" ]; then
            echo "❌ Usage: $0 --diagnose URL"
            exit 1
        fi
        check_dependencies || exit 1
        diagnose_url "$2"
        exit 0
        ;;
    "--list-urls"|"--list")
        list_urls
        exit 0
        ;;
    "--install-deps")
        install_system_deps
        exit 0
        ;;
    "--keywords")
        manage_keywords
        exit 0
        ;;
    "--monitor"|"")
        # Continue avec la surveillance normale
        :
        ;;
    *)
        echo "❌ Option invalide: $1"
        echo ""
        show_help
        exit 1
        ;;
esac

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

trap 'echo "Interruption détectée..."; log_message "INTERRUPTION: Arrêt forcé"; exit 1' INT TERM

main "$@"
