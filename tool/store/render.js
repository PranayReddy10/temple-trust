// Renders the Google Play store graphics for Darshan Saathi Trust:
//   store/play/icon-512.png             app icon (512×512, square, opaque)
//   store/play/feature-graphic.png      1024×500
//   store/play/screenshots/NN-*.png     1080×1920 phone screenshots
// The screenshots frame real app screens captured into store/raw/ (from the
// app with demo data) under a short headline.
//   node tool/store/render.js   (needs Playwright's Chromium; set PLAYWRIGHT
//   to its module path if it is installed globally)
const fs = require('fs');
const path = require('path');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

const APP = path.resolve(__dirname, '../..');
const OUT = path.join(APP, 'store/play');
const RAW = path.join(APP, 'store/raw');
const font = f => `file://${path.join(APP, 'assets/fonts', f)}`;
const C = { gold: '#C9A227', goldLight: '#F2C94C', sandal: '#F5EBDC', ivory: '#FFFDF9', deep: '#3E2723', kumkum: '#9B1B30', teak: '#5D4037', saffron: '#E07A1F' };

const mark = (fg, ac) => `
  <path d="M50 12c5 6 7 10 7 14a7 7 0 0 1-14 0c0-4 2-8 7-14z" fill="${ac}"/>
  <ellipse cx="50" cy="35" rx="4.5" ry="3" fill="${fg}"/>
  <path d="M42 40h16l2 7H40z" fill="${fg}"/>
  <path d="M37 48h26l2.5 8h-31z" fill="${fg}"/>
  <path d="M32 57h36l3 9H29z" fill="${fg}"/>
  <path d="M26 67h48l3 10H23z" fill="${fg}"/>
  <path d="M20 78h60v10H20z" fill="${fg}"/>
  <path d="M44 88v-9a6 6 0 0 1 12 0v9z" fill="${ac}"/>`;

// The same icon as the app's launcher (tool/brand/render.js), square:
// Play rounds it itself and wants no transparency.
const icon = (radius = 0) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${C.teak}"/><stop offset="1" stop-color="${C.deep}"/></linearGradient>
  <linearGradient id="b" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8A6A1F"/><stop offset=".5" stop-color="${C.goldLight}"/><stop offset="1" stop-color="#8A6A1F"/></linearGradient></defs>
  <rect width="100" height="100" rx="${radius}" fill="url(#g)"/>
  <rect x="5" y="5" width="90" height="90" rx="${Math.max(0, radius - 4)}" fill="none" stroke="${C.gold}" stroke-opacity=".35" stroke-width="1.2"/>
  <g transform="translate(15 6) scale(0.7)">${mark(C.sandal, C.goldLight)}</g>
  <rect x="18" y="74" width="64" height="15" rx="3" fill="url(#b)"/>
  <text x="50" y="85.5" text-anchor="middle" font-family="Serif" font-weight="700" font-size="11" letter-spacing="2.2" fill="${C.deep}">TRUST</text>
</svg>`;

const base = `
  @font-face { font-family: Serif; src: url('${font('NotoSerif_600SemiBold.ttf')}'); font-weight: 600 700; }
  @font-face { font-family: Serif; src: url('${font('NotoSerif_400Regular.ttf')}'); font-weight: 400; }
  @font-face { font-family: Sans; src: url('${font('NotoSans_400Regular.ttf')}'); font-weight: 400; }
  @font-face { font-family: Sans; src: url('${font('NotoSans_700Bold.ttf')}'); font-weight: 700; }
  * { margin: 0; box-sizing: border-box; }
  body { width: var(--w); height: var(--h); overflow: hidden; font-family: Sans, sans-serif; }`;

const dataUrl = file => `data:image/png;base64,${fs.readFileSync(file).toString('base64')}`;

const featureGraphic = () => `<html><head><style>${base}
  body { --w: 1024px; --h: 500px; background: radial-gradient(120% 140% at 0% 0%, ${C.teak} 0%, ${C.deep} 70%); color: ${C.sandal}; position: relative; }
  .glow { position: absolute; right: -80px; top: -120px; width: 620px; height: 620px; border-radius: 50%; background: radial-gradient(circle, rgba(242,201,76,.35), rgba(242,201,76,0) 65%); }
  .copy { position: absolute; left: 64px; top: 0; bottom: 0; width: 520px; display: flex; flex-direction: column; justify-content: center; gap: 18px; }
  .brand { display: flex; align-items: center; gap: 18px; }
  .brand svg { width: 92px; height: 92px; border-radius: 22px; box-shadow: 0 10px 30px rgba(0,0,0,.35); }
  h1 { font-family: Serif; font-weight: 700; font-size: 46px; line-height: 1.08; color: ${C.ivory}; }
  h1 span { color: ${C.goldLight}; }
  p { font-size: 22px; line-height: 1.4; color: #EADBC4; }
  .chips { display: flex; gap: 10px; flex-wrap: wrap; }
  .chips b { font-size: 15px; font-weight: 700; padding: 7px 14px; border-radius: 999px; background: rgba(242,201,76,.16); border: 1px solid rgba(242,201,76,.45); color: ${C.goldLight}; }
  .phone { position: absolute; right: 70px; top: 46px; width: 300px; height: 600px; border-radius: 38px; padding: 10px; background: #1b1210; box-shadow: 0 30px 60px rgba(0,0,0,.5); transform: rotate(-4deg); }
  .phone img { width: 100%; height: 100%; object-fit: cover; object-position: top; border-radius: 30px; }
</style></head><body><div class="glow"></div>
  <div class="copy">
    <div class="brand">${icon(22)}<h1>Darshan Saathi<br><span>Trust</span></h1></div>
    <p>Run your temple on Darshan Saathi: timings, sevas, bookings, hundi and payouts.</p>
    <div class="chips"><b>Timings</b><b>Seva bookings</b><b>Scan at counter</b><b>Online hundi</b></div>
  </div>
  <div class="phone"><img src="${dataUrl(path.join(RAW, '02-dashboard.png'))}"></div>
</body></html>`;

// Headline over each real screen, in the brand's colours.
const SHOTS = [
  ['01-home', 'Your temple, in your pocket', 'Everything your temple needs, in one place'],
  ['02-dashboard', 'Today at your temple, at a glance', 'Sevas, people, hundi and what is coming up'],
  ['03-bookings', 'Every seva booking, by day', 'Who is coming, what they paid, who has arrived'],
  ['08-timings', 'Timings devotees can trust', 'Every day, weekdays, and different hours on Sat & Sun'],
  ['04-finance', 'Clear accounts', 'What devotees paid, and every payout to your bank'],
  ['05-hundi', 'Online hundi', 'Gifts from devotees, straight to the temple'],
  ['07-events', 'Festivals, bhajans and events', 'Publish them, and see who is coming'],
  ['06-sevas', 'Sevas devotees book in the app', 'Fees, time slots and booking, all in one place'],
];
const shot = ([file, title, sub], i) => `<html><head><style>${base}
  body { --w: 1080px; --h: 1920px; background: linear-gradient(170deg, ${i % 2 ? C.kumkum : C.teak} 0%, ${i % 2 ? '#5E0F1D' : C.deep} 100%); color: ${C.ivory}; position: relative; }
  .glow { position: absolute; left: 50%; top: 0; width: 1200px; height: 900px; transform: translate(-50%, -45%); border-radius: 50%; background: radial-gradient(circle, rgba(242,201,76,.28), rgba(242,201,76,0) 62%); }
  header { position: absolute; top: 96px; left: 80px; right: 80px; text-align: center; }
  h1 { font-family: Serif; font-weight: 700; font-size: 74px; line-height: 1.12; }
  p { margin-top: 22px; font-size: 38px; line-height: 1.35; color: #F1E4CF; }
  .phone { position: absolute; left: 50%; bottom: -60px; width: 820px; height: 1560px; transform: translateX(-50%); border-radius: 76px; padding: 18px; background: #160e0c; box-shadow: 0 40px 90px rgba(0,0,0,.45); }
  .phone img { width: 100%; height: 100%; object-fit: cover; object-position: top; border-radius: 60px; }
</style></head><body><div class="glow"></div>
  <header><h1>${title}</h1><p>${sub}</p></header>
  <div class="phone"><img src="${dataUrl(path.join(RAW, file + '.png'))}"></div>
</body></html>`;

(async () => {
  const browser = await chromium.launch();
  const render = async (html, width, height, file) => {
    const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
    await page.setContent(html, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: file, omitBackground: false });
    await page.close();
    console.log(path.relative(APP, file));
  };
  fs.mkdirSync(path.join(OUT, 'screenshots'), { recursive: true });
  await render(`<html><head><style>${base} body{--w:512px;--h:512px} svg{width:512px;height:512px;display:block}</style></head><body>${icon(0)}</body></html>`, 512, 512, path.join(OUT, 'icon-512.png'));
  await render(featureGraphic(), 1024, 500, path.join(OUT, 'feature-graphic.png'));
  for (const [i, s] of SHOTS.entries()) {
    await render(shot(s, i), 1080, 1920, path.join(OUT, 'screenshots', `${String(i + 1).padStart(2, '0')}-${s[0].slice(3)}.png`));
  }
  await browser.close();
})();
