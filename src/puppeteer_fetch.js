const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

const fs = require('fs');
const url = process.argv[2];
const outputFile = process.argv[3];

if (!url || !outputFile) {
    console.error('Usage: node puppeteer_fetch.js <URL> <output_file>');
    process.exit(1);
}

(async () => {
    let browser;
    try {
        console.error('🚀 Lancement de Puppeteer avec stealth...');
        browser = await puppeteer.launch({
            headless: true,
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu',
                '--disable-web-security',
                '--disable-features=VizDisplayCompositor',
                '--window-size=1920,1080'
            ],
            timeout: 60000
        });

        console.error('✅ Navigateur lancé (stealth activé)');
        
        const page = await browser.newPage();
        await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
        await page.setViewport({ width: 1920, height: 1080 });
        await page.setDefaultNavigationTimeout(90000);
        await page.setDefaultTimeout(30000);

        await page.setRequestInterception(true);
        page.on('request', (req) => {
            const resourceType = req.resourceType();
            if (['image', 'font', 'media'].includes(resourceType)) {
                req.abort();
            } else {
                req.continue();
            }
        });

        page.on('error', (err) => {
            console.error('❌ Erreur de page:', err.message);
        });

        page.on('pageerror', (err) => {
            console.error('⚠️  Erreur JavaScript:', err.message);
        });

        console.error(`🌐 Navigation vers ${url}...`);

        await page.goto(url, { 
            waitUntil: ['domcontentloaded', 'networkidle2'],
            timeout: 90000
        });

        console.error('✅ Page chargée, attente du contenu...');

        await new Promise(resolve => setTimeout(resolve, 5000));

        await page.evaluate(async () => {
            await new Promise((resolve) => {
                let totalHeight = 0;
                const distance = 100;
                const timer = setInterval(() => {
                    const scrollHeight = document.body.scrollHeight;
                    window.scrollBy(0, distance);
                    totalHeight += distance;
                    
                    if (totalHeight >= scrollHeight || totalHeight > 5000) {
                        clearInterval(timer);
                        resolve();
                    }
                }, 100);
            });
        });

        await new Promise(resolve => setTimeout(resolve, 2000));

        const html = await page.content();

        fs.writeFileSync(outputFile, html);

        const stats = fs.statSync(outputFile);
        console.error(`✅ Fichier sauvegardé: ${stats.size} bytes`);

    } catch (error) {
        console.error(`❌ Erreur Puppeteer: ${error.message}`);
        process.exit(1);
    } finally {
        if (browser) {
            await browser.close();
        }
    }
})();

