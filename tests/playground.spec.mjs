import { test, expect } from '@playwright/test';

test('each button calls Rust successfully, then the full suite repeats', async ({ page }, testInfo) => {
  const errors = [];
  const assets = new Set();
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => assets.add(new URL(response.url()).pathname));
  const compiler = testInfo.project.metadata.compiler;
  await page.goto(`/?compiler=${compiler}`);
  await expect(page.locator('#compiler')).toHaveText(`Running ${compiler}`);
  await expect(page.getByRole('status')).toHaveText('Ready');
  const output = compiler === 'dart2wasm' ? 'wasm' : 'js';
  const otherOutput = compiler === 'dart2wasm' ? 'js' : 'wasm';
  expect(assets.has(`/main.dart.${output}`)).toBe(true);
  expect(assets.has(`/main.dart.${otherOutput}`)).toBe(false);
  const buttons = page.getByRole('region', { name: 'Call patterns' }).getByRole('button');
  const names = await buttons.allTextContents();
  expect(names.length).toBe(30);
  for (const [index, name] of names.entries()) {
    await page.getByRole('button', { name, exact: true }).click();
    await expect(page.locator('#counts')).toHaveText(`${index + 1} passed · 0 failed`);
    await expect(page.locator('.result').first()).toContainText(`PASS · ${name}`);
  }
  await page.getByRole('button', { name: 'Clear results', exact: true }).click();
  await expect(page.locator('#counts')).toHaveText('0 passed · 0 failed');
  await expect(page.locator('.result')).toHaveCount(0);
  for (let run = 1; run <= 3; run++) {
    await page.getByRole('button', { name: 'Run all patterns', exact: true }).click();
    await expect(page.locator('#counts')).toHaveText(`${run * names.length} passed · 0 failed`);
    await expect(page.locator('.fail')).toHaveCount(0);
  }
  expect(errors).toEqual([]);
});
