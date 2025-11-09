#!/bin/bash
set -e

# Se place à la racine du projet (un dossier au-dessus de 'scripts/')
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)
PUPPETEER_DIR="$PROJECT_ROOT/puppeteer_module"

echo "📦 Setting up Puppeteer in $PUPPETEER_DIR..."

mkdir -p "$PUPPETEER_DIR"
cd "$PUPPETEER_DIR"

if [ ! -f "package.json" ]; then
    npm init -y > /dev/null 2>&1
fi

echo "Installing puppeteer-extra and stealth plugin..."
npm install puppeteer-extra puppeteer-extra-plugin-stealth --save

echo "✅ Puppeteer setup complete."
