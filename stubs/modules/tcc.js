/** Stub no-op de tcc.node (macOS). Recurso não essencial para gravar/resumir. */
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
