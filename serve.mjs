import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('./web/', import.meta.url));
const mime = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
};

createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const path = resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`);
    if (!path.startsWith(root.endsWith(sep) ? root : `${root}${sep}`)) {
      response.writeHead(403).end();
      return;
    }
    const data = await readFile(path);
    response.writeHead(200, {
      'Content-Type': mime[extname(path)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
    }).end(data);
  } catch {
    response.writeHead(404).end('Not found');
  }
}).listen(Number(process.argv[2] ?? 8765), '127.0.0.1', () => {
  console.log(`Playground: http://localhost:${process.argv[2] ?? 8765}/`);
});
