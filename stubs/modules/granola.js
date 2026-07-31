/**
 * Stub de granola.node, o módulo CENTRAL: captura de áudio do sistema.
 *
 * No macOS ele usa ScreenCaptureKit + CoreAudio + AVFoundation. É o único
 * módulo cuja substituição exige trabalho real (Fase 2 do projeto): implementar
 * captura via PipeWire/PulseAudio devolvendo o mesmo formato que o JS espera.
 *
 * Por enquanto ele apenas REGISTRA cada chamada. Isso é proposital e é a nossa
 * ferramenta de engenharia reversa: rodando o app com este stub, o log revela o
 * contrato real (nomes de métodos, ordem, argumentos, callbacks esperados) sem
 * precisar ler o bundle minificado. O resultado alimenta docs/findings.md.
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
    if (prop === "__calls") return calls; // introspecção para os scripts
    return (...args) => {
      record(prop, args);
      // Se o app passar callback, chamamos com "silêncio" para ele seguir o
      // fluxo e revelar as próximas etapas em vez de travar no primeiro erro.
      const cb = args.find((a) => typeof a === "function");
      if (cb) setImmediate(() => cb(null, null));
      return undefined;
    };
  },
};

module.exports = new Proxy({}, handler);
