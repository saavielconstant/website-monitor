#!/bin/bash
set -e

# Se place à la racine du projet
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)
DATA_DIR="$HOME/website_monitor"

echo "🚀 Starting installation for Website Monitor..."

# 1. Installer les dépendances système (via le script principal)
echo "--- 1. Installing system dependencies (sudo required)..."
# On appelle la fonction d'installation de dépendances du script principal
"$PROJECT_ROOT/src/website-monitor.sh" --install-deps

# 2. Configurer Puppeteer
echo "--- 2. Setting up Puppeteer..."
chmod +x "$PROJECT_ROOT/scripts/setup-puppeteer.sh"
"$PROJECT_ROOT/scripts/setup-puppeteer.sh"

# 3. Créer le dossier de données et copier les configurations
echo "--- 3. Setting up data directory at $DATA_DIR..."
mkdir -p "$DATA_DIR"

if [ ! -f "$DATA_DIR/url_list.txt" ]; then
    cp "$PROJECT_ROOT/config/url_list.txt.example" "$DATA_DIR/url_list.txt"
    echo "✅ Created $DATA_DIR/url_list.txt"
fi

if [ ! -f "$DATA_DIR/keywords.txt" ]; then
    cp "$PROJECT_ROOT/config/keywords.txt.example" "$DATA_DIR/keywords.txt"
    echo "✅ Created $DATA_DIR/keywords.txt"
fi

echo "🎉 Installation complete!"
echo "👉 Now, edit your URL list at: $DATA_DIR/url_list.txt"
echo "👉 And your keywords at: $DATA_DIR/keywords.txt"
echo "👉 Finally, run the monitor with: $PROJECT_ROOT/src/website-monitor.sh"
