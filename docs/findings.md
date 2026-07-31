# Achados da engenharia reversa

Levantamento sobre `Granola - AI Notepad.dmg`, app **v7.452.1** (build de
2026-07-30), analisado em 2026-07-31. Só observações, nenhum código do app
está reproduzido aqui.

## O app é Electron

- `Contents/Resources/app.asar`, 58,7 MB (93 MB desempacotado)
- `package.json`: `@granola/electron`, main = `dist-electron/main/index.js`
- Repo interno declarado: `github.com/granola-inc/granola-electron` (privado)
- O binário `Contents/MacOS/Granola` tem só 119 KB: é o launcher; o peso está
  no Electron Framework (`libEGL`, `libGLESv2`, `libvk_swiftshader`, `libffmpeg`)
- Auto-update via **Squirrel.Mac** (+ `Mantle`, `ReactiveObjC`)

## A arquitetura já é multiplataforma

Contagem em `dist-electron/main/index.js`:

| Sinal | Ocorrências |
|---|---|
| `process.platform` | 229 |
| `darwin` | 142 |
| **`win32`** | **124** |
| `linux` | 19 |

Caminhos de módulo nativo referenciados: `native/client`, `native/diarizer`,
**`native/windows`**.

**Leitura:** existe uma camada Windows quase tão extensa quanto a macOS. Portar
para Linux é escrever a *terceira* implementação da camada nativa, não
reescrever o produto. As 19 ocorrências de `linux` provavelmente são checagens
defensivas, a confirmar.

## Módulos nativos (todos Mach-O, código fechado)

`Contents/Resources/native/`, 15 arquivos:

| Módulo | Frameworks Apple | Essencial p/ gravar? |
|---|---|---|
| **granola** | **ScreenCaptureKit, CoreAudio, AVFoundation** | **SIM, é a captura** |
| diarizer (`native/diarizer`) |, | provável (separação de falantes) |
| keychain |, | sim (persistir login) |
| eventkit | EventKit | não (calendário) |
| screen_capture_ocr | ScreenCaptureKit | não |
| third_party_meeting_automation | AppKit | não (automatiza Zoom/Meet) |
| mac_webcam_sysext | AVFoundation | não |
| macos_mic_apps_with_devices | CoreAudio | não (lista apps usando mic) |
| docktile, haptics, mission_control, paste, procmem, sleep, tcc | AppKit e afins | não (integrações de SO) |

Módulos de terceiros em `app.asar.unpacked/node_modules`:
`better-sqlite3-multiple-ciphers`, `@napi-rs/*`, `keyspy`,
`electron-click-drag-plugin`, `registry-js` (Windows), `win-ca` (Windows).

> A presença de `registry-js` e `win-ca` no pacote **macOS** reforça que o
> mesmo bundle serve as duas plataformas.

## Processos do main

`dist-electron/` tem processos separados por função, vários com nome revelando
dependência de macOS:

```
audio_process              mic_monitor_process        mic_monitor_v2_process
eventkit_process           macos_mic_apps_with_devices_process
mission_control_process    speaker_embedding_process  sqlite_process
main                       preload
```

`speaker_embedding_process` sugere que parte da diarização roda **local**.

## Fase 1, obstáculos encontrados e resolvidos (2026-07-31)

Rodando `electron loader.js` com o app extraído, na ordem em que apareceram:

| # | Sintoma | Causa | Solução |
|---|---|---|---|
| 1 | `USER granola` não existe | uid 1000 já é do usuário `node` na imagem base | usar `USER ${UID}` numérico |
| 2 | `Electron failed to install correctly` | postinstall do npm não baixou o binário; em runtime não há permissão de escrita | baixar o zip do release oficial no build |
| 3 | Janela **preta**, `Exiting GPU process` | faltava `libGL.so.1` no container | instalar `libgl1 libglx-mesa0 libegl1 libgles2 libglapi-mesa libgl1-mesa-dri` |
| 4 | `net::ERR_FAILED` em todo `app://ui/...` | o handler usa `net.fetch('file://…')`, que o Chromium recusa aqui mesmo com o arquivo presente e legível | o loader intercepta `protocol.handle` e serve do disco (`serveFromDisk`) |
| 5 | `better_sqlite3.node: invalid ELF header` | binário Mach-O; e o hook de require do loader **não alcança o renderer**, que carrega o `.node` sozinho | compilar `better-sqlite3-multiple-ciphers` contra os headers do Electron e **sobrepor por bind-mount** no container |

Detalhes que custaram tempo e valem registrar:

- **Versão do Electron**: `CFBundleVersion` do `Electron Framework.framework/Versions/A/Resources/Info.plist` → **42.7.0**. O `CFBundleShortVersionString` vem vazio.
- **Compilação do sqlite**: `npm install --runtime=electron --target=...` **não** funciona (npm não repassa ao node-gyp); é preciso `npm_config_runtime` / `npm_config_target` / `npm_config_disturl` como variáveis de ambiente. Além disso, a versão do bundle (12.9.0) **não compila** contra o V8 do Electron 42 (erros `SetNativeDataProperty ambiguous`, `External::Value()`); a **12.11.1** compila e é compatível.
- **`process.resourcesPath` e `app.getAppPath()`** apontam para o diretório do Electron quando se roda `electron <script>`; ambos precisam ser redirecionados para o app extraído.
- **Screenshot de janela no i3 não é prova**: janela em workspace não visível é capturada como preta mesmo estando saudável. Validar por log (`ERR_FAILED`, `Uncaught`) em vez da imagem.

### Estado ao fim da Fase 1

Com tudo acima aplicado: app inicia, `primary-window-created` + `ready-to-show`, protocolo `app://` serve os 322 assets, sqlite carrega, e o log fica **sem nenhum erro de JavaScript**. Registros do próprio app confirmam a inicialização completa:
`app-started {"wasFirstLaunch":true}`, `auth-electron-user-logged-in {"loggedIn":false}`, `system-info` com a CPU correta.

**Nenhum stub nativo foi chamado até aqui**, ou seja, a UI monta sem depender dos módulos macOS. Eles só devem entrar em cena no login e, principalmente, na gravação (Fase 2).

## Pendências de investigação

1. **Versão do Electron do bundle**, ainda não determinada. `package.json` não
   declara; o `Info.plist` do Electron Framework não foi extraído no primeiro
   passe. Necessária para casar a ABI dos módulos nativos recompilados.
2. **Contrato do `granola.node`**, nomes de métodos, argumentos e formato do
   buffer de áudio. O stub em `stubs/modules/granola.js` registra cada chamada
   justamente para revelar isso em runtime.
3. **Attestation no backend**, o servidor aceita cliente não-oficial? É o que
   a Fase 1 responde e o que decide a viabilidade do projeto inteiro.
4. **Onde roda a diarização**, local (`speaker_embedding_process`) ou servidor.
