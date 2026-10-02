// Renders the Darshan Saathi Trust icons: the Darshan Saathi mark (the
// gopuram with the lamp, see temple-app/tool/brand/mark.js) in brass on the
// temple-door teak, with a TRUST band, so the two apps are told apart on a
// home screen at a glance.
//   node tool/brand/render.js   (from temple-trust; needs Playwright's Chromium,
//   set PLAYWRIGHT to its module path if it is installed globally)
const fs = require('fs');
const path = require('path');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

const APP = path.resolve(__dirname, '../..');
const C = { gold: '#C9A227', goldLight: '#F2C94C', sandal: '#F5EBDC', deep: '#3E2723', kumkum: '#9B1B30', teak: '#5D4037' };

const mark = (fg, ac) => `
  <path d="M50 12c5 6 7 10 7 14a7 7 0 0 1-14 0c0-4 2-8 7-14z" fill="${ac}"/>
  <ellipse cx="50" cy="35" rx="4.5" ry="3" fill="${fg}"/>
  <path d="M42 40h16l2 7H40z" fill="${fg}"/>
  <path d="M37 48h26l2.5 8h-31z" fill="${fg}"/>
  <path d="M32 57h36l3 9H29z" fill="${fg}"/>
  <path d="M26 67h48l3 10H23z" fill="${fg}"/>
  <path d="M20 78h60v10H20z" fill="${fg}"/>
  <path d="M44 88v-9a6 6 0 0 1 12 0v9z" fill="${ac}"/>`;

// The icon: teak gradient, the mark raised a little, a brass band reading TRUST.
const icon = ({ radius = 0, band = true, scale = 0.7 } = {}) => {
  const off = (100 - 100 * scale) / 2;
  const lift = band ? 9 : 0;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${C.teak}"/><stop offset="1" stop-color="${C.deep}"/></linearGradient>
  <linearGradient id="b" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8A6A1F"/><stop offset=".5" stop-color="${C.goldLight}"/><stop offset="1" stop-color="#8A6A1F"/></linearGradient></defs>
  <rect width="100" height="100" rx="${radius}" fill="url(#g)"/>
  <rect x="5" y="5" width="90" height="90" rx="${Math.max(0, radius - 4)}" fill="none" stroke="${C.gold}" stroke-opacity=".35" stroke-width="1.2"/>
  <g transform="translate(${off} ${off - lift}) scale(${scale})">${mark(C.sandal, C.goldLight)}</g>
  ${band ? `<rect x="18" y="74" width="64" height="15" rx="3" fill="url(#b)"/>
  <text x="50" y="85.5" text-anchor="middle" font-family="Georgia, 'Noto Serif', serif" font-weight="700" font-size="11" letter-spacing="2.2" fill="${C.deep}">TRUST</text>` : ''}
</svg>`;
};

const jobs = [];
const png = (file, size, opts = {}) => jobs.push({ file, size, svg: icon(opts), transparent: !!opts.radius });

const dens = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [d, m] of Object.entries(dens)) png(`${APP}/android/app/src/main/res/mipmap-${d}/ic_launcher.png`, 48 * m);

const ios = JSON.parse(fs.readFileSync(`${APP}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`, 'utf8'));
for (const img of ios.images) {
  if (!img.filename) continue;
  const px = Math.round(parseFloat(img.size) * parseFloat(img.scale));
  // Tiny sizes (settings, notifications) drop the band: it would be a smudge.
  png(`${APP}/ios/Runner/Assets.xcassets/AppIcon.appiconset/${img.filename}`, px, { band: px >= 80 });
}

png(`${APP}/web/favicon.png`, 64, { radius: 18, band: false, scale: 0.86 });
png(`${APP}/web/icons/Icon-192.png`, 192, { radius: 22 });
png(`${APP}/web/icons/Icon-512.png`, 512, { radius: 22 });
png(`${APP}/web/icons/Icon-maskable-192.png`, 192, { scale: 0.56 });
png(`${APP}/web/icons/Icon-maskable-512.png`, 512, { scale: 0.56 });
// Shown in the app itself: sign-in and the account screen.
png(`${APP}/assets/brand/logo.png`, 512, { radius: 22 });

// Masters, for the store listing and print.
const lockup = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 470 100">${icon({ radius: 22 }).replace(/^<svg[^>]*>|<\/svg>$/g, '')}
  <text x="116" y="56" font-family="Georgia, 'Noto Serif', serif" font-weight="700" font-size="38" fill="${C.deep}">Darshan Saathi</text>
  <text x="118" y="82" font-family="system-ui, 'Segoe UI', sans-serif" font-weight="700" font-size="15" letter-spacing="5" fill="${C.kumkum}">TRUST</text></svg>`;
fs.writeFileSync(`${APP}/tool/brand/logo-icon.svg`, icon({ radius: 22 }));
fs.writeFileSync(`${APP}/tool/brand/logo-lockup.svg`, lockup);

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const j of jobs) {
    await page.setViewportSize({ width: j.size, height: j.size });
    await page.setContent(`<html><body style="margin:0;background:transparent">${j.svg.replace('<svg ', `<svg width="${j.size}" height="${j.size}" `)}</body></html>`);
    fs.mkdirSync(path.dirname(j.file), { recursive: true });
    await page.screenshot({ path: j.file, omitBackground: j.transparent, clip: { x: 0, y: 0, width: j.size, height: j.size } });
    console.log(`${path.relative(APP, j.file)}  ${j.size}`);
  }
  await browser.close();
})();
