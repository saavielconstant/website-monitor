# Advanced Website Monitor

Un script Bash puissant pour surveiller les changements sur des sites web, avec gestion de JavaScript (Puppeteer), surveillance de zones et alertes par mots-clés.

## Fonctionnalités

* **Récupération Hybride:** `curl` + **Puppeteer avec Stealth**
* **Surveillance de Zone:** Ciblez des parties spécifiques d'une page.
* **Détection par Mots-clés:** Alertes basées sur des mots-clés dans le `diff`.
* **Rapports HTML:** Un rapport clair classé par catégorie.
* **Alertes:** `zenity` (Desktop) et `Telegram`.

## Installation Rapide

```bash
git clone [https://github.com/VOTRE_NOM/VOTRE_PROJET.git](https://github.com/VOTRE_NOM/VOTRE_PROJET.git)
cd VOTRE_PROJET
chmod +x scripts/install.sh
./scripts/install.sh
