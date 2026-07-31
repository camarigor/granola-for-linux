/** No-op stub for tcc.node (macOS). Not required for recording or summarising. */
module.exports = new Proxy({}, {
  get(_t, prop) {
    if (prop === "then" || typeof prop === "symbol") return undefined;
    return (...args) => {
      if (process.env.GRANOLA_STUB_VERBOSE !== "0")
        console.log(`[stub:tcc] ${String(prop)}(${args.length} args) -> no-op`);
      return undefined;
    };
  },
});
