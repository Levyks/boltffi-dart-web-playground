# Dart web playground

A plain Dart web page calling real Rust WASM through the experimental Dart web bindings. No Flutter and no mocked exports.

This is a separate repository. Its local dependencies expect this layout:

```text
~/dev/boltffi-dart-web-playground/
~/dev/libs/boltffi/
```

From this directory, with Rust, Node.js, and Dart 3.10.8 or newer available:

```powershell
./build.ps1 -Serve
```

If Dart is managed by FVM, pass its executable:

```powershell
./build.ps1 -Dart "$env:USERPROFILE/fvm/default/bin/dart.bat" -Serve
```

The build compiles the same Dart entry point with both dart2js and dart2wasm. Open http://localhost:8765 and use the compiler links, or go directly to http://localhost:8765/?compiler=dart2wasm (the default is dart2js). The WASM mode loads Dart's emitted `.mjs` bootstrap and `.wasm` directly, without falling back to JavaScript.

Every button checks its expected result and prints PASS or FAIL with the returned value. Run all patterns executes the same checks sequentially. Timings include scheduling and intentional delays; this is a correctness playground, not a benchmark.

To serve an existing build: `node serve.mjs`. To rebuild with an existing CLI: `./build.ps1 -Boltffi ../libs/boltffi/target/debug/boltffi.exe`.

For repeatable browser automation after building:

```powershell
npx playwright install chromium
npm test
```

The test runs as two projects, `dart2js` and `dart2wasm`. For each compiler it verifies which compiled output was loaded, clicks every pattern individually, checks the result, clears the log, then repeats the full suite three times. It starts its own server on port 8766 and checks for uncaught page errors. Run only one compiler with `npm test -- --project=dart2wasm` or `--project=dart2js`.

Patterns include sync values and UTF-8 strings, defaults, optional values, records, typed vectors, bytes and empty buffers, bool and int64 vectors, mutable direct records (including mutation before an error), data enums, class factories and disposal, successful and failed string/record results, async values and typed errors, concurrent futures, cancellation before starting/while pending/inside the first poll, closure and trait callbacks, callback errors, genuinely asynchronous Dart callbacks, async/batch/callback streams, record streams, pause/resume, and idle subscription cancellation.

Encoded mutable parameters, such as `&mut Message` with a String field, have no WASM writeback channel and are rejected during binding generation. The mutable examples use a direct `Point` record. Web Dart int64 values are checked at the exact integer boundary (±9007199254740991).

The build uses the local TypeScript runtime and CLI. Rust is built in release mode; `wasm-opt` is used when available, and skipped with a warning otherwise. Generated bindings and binaries are ignored; source and dependency lockfiles are retained.
