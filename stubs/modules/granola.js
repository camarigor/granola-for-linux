/**
 * Stub for granola.node - the CORE module: system audio capture.
 *
 * On macOS it uses ScreenCaptureKit + CoreAudio + AVFoundation. It is the only
 * module whose replacement takes real work (project Phase 2): implementing
 * capture over PipeWire/PulseAudio returning the format the JS expects.
 *
 * For now it only RECORDS every call. That is deliberate: it is our
 * reverse-engineering tool - running the app with this stub makes the log reveal
 * the real contract (method names, order, arguments, expected callbacks)
 * without reading the minified bundle. The result feeds docs/findings.md.
 */
const calls = [];

function record(prop, args) {
  const entry = {
    t: new Date().toISOString(),
    method: String(prop),
    argc: args.length,
    argTypes: args.map((a) => (a === null ? "null" : typeof a)),
  };
  calls.push(entry);
  console.log(`[stub:granola] ${entry.method}(${entry.argTypes.join(", ")})`);
  return entry;
}

const handler = {
  get(_target, prop) {
    if (prop === "then" || typeof prop === "symbol") return undefined;
    if (prop === "__calls") return calls; // introspection for the scripts
    return (...args) => {
      record(prop, args);
      // If the app passes a callback we answer with silence so it keeps going
      // and reveals later stages instead of stalling on the first error.
      const cb = args.find((a) => typeof a === "function");
      if (cb) setImmediate(() => cb(null, null));
      return undefined;
    };
  },
};

module.exports = new Proxy({}, handler);
