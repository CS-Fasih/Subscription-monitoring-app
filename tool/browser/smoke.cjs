const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require('playwright');

const base = process.env.TALLY_BASE_URL || 'http://127.0.0.1:8080';
const root = path.resolve(__dirname, '../..');
const screenshots = process.env.TALLY_SCREENSHOTS_DIR || path.join(root, 'docs/screenshots');
const results = path.join(__dirname, 'results');
const errors = [];
const externalRequests = new Set();

async function ready(page) {
  await page.waitForSelector('flutter-view', { timeout: 60000 });
  await page.waitForFunction(() => !document.getElementById('loading'));
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.getByRole('button', { name: 'Renewal inbox', exact: true }).waitFor();
}

async function state(page) {
  return page.evaluate(() => {
    const key = Object.keys(localStorage).find(key => key.endsWith('tally.state.v1'));
    let result = JSON.parse(localStorage.getItem(key));
    if (typeof result === 'string') result = JSON.parse(result);
    return result;
  });
}

async function typeField(page, name, value) {
  // Focus adds the hint to Flutter's accessible name; retain the stable label.
  const field = page.getByRole('textbox', { name });
  await field.click();
  // Flutter attaches its native browser editor after a focus frame.
  await page.waitForTimeout(150);
  await field.fill(value);
  assert.equal(await field.inputValue(), value);
  await field.press('Tab');
  await page.waitForTimeout(100);
}

async function download(page, button, extension) {
  const pending = page.waitForEvent('download');
  await page.getByRole('button', { name: button, exact: true }).click();
  const file = await pending;
  assert(file.suggestedFilename().endsWith(extension));
  const target = path.join(results, file.suggestedFilename());
  await file.saveAs(target);
  return fs.readFile(target, 'utf8');
}

(async () => {
  await fs.mkdir(screenshots, { recursive: true });
  await fs.mkdir(results, { recursive: true });
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  try {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1040 }, acceptDownloads: true });
    const page = await context.newPage();
    page.on('pageerror', error => errors.push(error.message));
    page.on('request', request => {
      if (request.url().startsWith('http') && new URL(request.url()).origin !== new URL(base).origin) {
        externalRequests.add(request.url());
      }
    });
    await page.goto(base);
    await ready(page);
    assert.equal((await state(page)).subscriptions.length, 8);
    await page.screenshot({ path: path.join(screenshots, 'overview-desktop.png') });
    console.log('PASS: release app starts with an explicitly labeled demo workspace');

    await page.getByRole('button', { name: 'Add subscription', exact: true }).click();
    await typeField(page, 'Subscription name', 'Browser test plan');
    await typeField(page, 'Price (USD)', '18.25');
    await page.getByRole('dialog').getByRole('button', { name: 'Add subscription', exact: true }).click();
    await page.getByRole('dialog').waitFor({ state: 'hidden' });
    await page.reload();
    await ready(page);
    assert.equal((await state(page)).subscriptions.find(s => s.name === 'Browser test plan').amountCents, 1825);
    console.log('PASS: subscription creation survives a real browser reload');

    await page.getByRole('button', { name: 'Settings', exact: true }).click();
    const backup = await download(page, 'Export JSON', '.json');
    assert.equal(JSON.parse(backup).subscriptions.length, 9);
    const csv = await download(page, 'Export CSV', '.csv');
    assert(csv.includes('Browser test plan'));
    assert(csv.includes('18.25'));
    const calendar = await download(page, 'Export calendar', '.ics');
    assert(calendar.startsWith('BEGIN:VCALENDAR\r\n'));
    assert(calendar.includes('BEGIN:VALARM'));
    assert(calendar.includes('Browser test plan'));
    console.log('PASS: real JSON, CSV, and calendar downloads contain the expected data');

    const chooserPromise = page.waitForEvent('filechooser');
    await page.getByRole('button', { name: 'Import backup', exact: true }).click();
    const chooser = await chooserPromise;
    await chooser.setFiles({ name: 'tally-backup.json', mimeType: 'application/json', buffer: Buffer.from(backup) });
    await page.getByRole('button', { name: 'Restore backup', exact: true }).click();
    await page.getByText('Backup restored. Your subscriptions and preferences are ready.', { exact: true }).first().waitFor();
    assert.equal((await state(page)).subscriptions.length, 9);
    console.log('PASS: exported backup restores through the actual file picker');

    await page.getByRole('button', { name: 'Renewal calendar', exact: true }).click();
    await page.screenshot({ path: path.join(screenshots, 'calendar-desktop.png') });
    await page.getByRole('button', { name: 'Insights', exact: true }).click();
    await page.screenshot({ path: path.join(screenshots, 'insights-desktop.png') });
    await page.getByRole('button', { name: 'Smart tools', exact: true }).click();
    await page.screenshot({ path: path.join(screenshots, 'tools-desktop.png') });

    await page.evaluate(() => navigator.serviceWorker.ready);
    await page.waitForFunction(() => !!navigator.serviceWorker.controller, null, { timeout: 60000 });
    await context.setOffline(true);
    await page.reload();
    await ready(page);
    assert.equal((await state(page)).subscriptions.length, 9);
    await page.getByRole('button', { name: 'Add subscription', exact: true }).click();
    await typeField(page, 'Subscription name', 'Offline plan');
    await typeField(page, 'Price (USD)', '2.50');
    await page.getByRole('dialog').getByRole('button', { name: 'Add subscription', exact: true }).click();
    await page.getByRole('dialog').waitFor({ state: 'hidden' });
    await page.reload();
    await ready(page);
    assert((await state(page)).subscriptions.some(s => s.name === 'Offline plan' && s.amountCents === 250));
    console.log('PASS: offline startup and offline edits persist across reloads');
    await context.setOffline(false);

    // A separate empty browser profile exercises real mobile layout without test records.
    const mobile = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
    const phone = await mobile.newPage();
    phone.on('pageerror', error => errors.push(error.message));
    await phone.goto(base);
    await ready(phone);
    await phone.screenshot({ path: path.join(screenshots, 'overview-mobile.png') });
    await phone.getByRole('tab', { name: 'Plans', exact: true }).click();
    await phone.screenshot({ path: path.join(screenshots, 'subscriptions-mobile.png') });
    console.log('PASS: mobile release app renders and navigates');
    assert.deepEqual(errors, [], 'No uncaught application errors');
    assert.deepEqual([...externalRequests], [], 'App assets are bundled and stay on the serving origin');
    console.log('PASS: no uncaught JavaScript errors or third-party asset requests');
    await mobile.close();
    await context.close();
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
