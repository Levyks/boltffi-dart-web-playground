import './generated/playground_web_loader.mjs';

const compiler = new URLSearchParams(location.search).get('compiler') ?? 'dart2js';
document.querySelector('#compiler').textContent = `Running ${compiler}`;

try {
  if (compiler === 'dart2wasm') {
    const { compileStreaming } = await import('./main.dart.mjs');
    const compiled = await compileStreaming(fetch('./main.dart.wasm'));
    const app = await compiled.instantiate();
    app.invokeMain();
  } else if (compiler === 'dart2js') {
    await new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'main.dart.js';
      script.onload = resolve;
      script.onerror = () => reject(new Error('Could not load dart2js output'));
      document.body.append(script);
    });
  } else {
    throw new Error(`Unknown compiler: ${compiler}`);
  }
} catch (error) {
  document.querySelector('#status').textContent = `${compiler} startup failed: ${error}`;
  console.error(error);
}
