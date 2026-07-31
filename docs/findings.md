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
