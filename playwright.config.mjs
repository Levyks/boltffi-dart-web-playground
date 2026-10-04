import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  workers: 1,
  projects: [
    { name: 'dart2js', metadata: { compiler: 'dart2js' } },
    { name: 'dart2wasm', metadata: { compiler: 'dart2wasm' } },
  ],
  use: { baseURL: 'http://127.0.0.1:8766', browserName: 'chromium' },
  webServer: {
    command: 'node serve.mjs 8766',
    url: 'http://127.0.0.1:8766',
    reuseExistingServer: false,
  },
});
