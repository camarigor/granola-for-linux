# Stubs

Substitutos JS para os módulos nativos macOS do Granola. `loader.js` intercepta
o carregador de `.node` do Node e injeta estes arquivos, assim o bundle
minificado **não precisa ser editado** (o que quebraria a cada release do app).

| Stub | Estratégia |
|---|---|
| `granola.js` | **Instrumentado.** Registra toda chamada (método, tipos dos argumentos) e responde a callbacks com "silêncio" para o app seguir o fluxo. É a ferramenta que revela o contrato da captura de áudio para a Fase 2. |
| `keychain.js` | Implementação real simplificada: arquivo 600 em `~/.config/granola-linux`. Trocar por libsecret depois. |
| demais | No-op via Proxy: qualquer método retorna `undefined` e loga a chamada. São integrações de SO (Dock, haptics, OCR, automação de reunião) que não afetam gravar/resumir. |

Módulos ainda sem stub aparecem no log como `FALTA STUB: <nome>`, o loader
devolve um objeto que lança erro descritivo em vez de derrubar o app, para que
uma execução revele tudo que falta de uma vez.

Variáveis: `GRANOLA_STUB_VERBOSE=0` silencia os logs; `GRANOLA_APP_DIR` aponta
para outro diretório do app extraído.
