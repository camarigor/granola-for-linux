# granola-linux

Tentativa de rodar o cliente **Granola** (macOS, Electron) no Linux.

> **Este repositório não contém nenhum código, binário ou recurso do Granola.**
> O app é proprietário. Os scripts aqui extraem a **sua própria cópia** do `.dmg`
> oficial, na sua máquina, e aplicam patches locais. Nada do app é redistribuído.

## Por que isso é possível (e onde trava)

O Granola é Electron, então a lógica de produto é JavaScript, que roda em
qualquer plataforma. O que é específico de macOS são **15 módulos nativos**
(`.node`, Mach-O, código fechado) em `Contents/Resources/native/`.

Levantamento feito na v7.452.1 (ver `docs/findings.md`):

| Sinal | Valor | Leitura |
|---|---|---|
| `process.platform` no main | 229 ocorrências | lógica por plataforma é extensa |
| strings `darwin` / `win32` / `linux` | 142 / **124** / 19 | **já existe camada Windows**, a arquitetura é multiplataforma |
| módulos nativos | 15 (todos Mach-O) | precisam de equivalente Linux ou stub |
| captura de áudio | ScreenCaptureKit + CoreAudio + AVFoundation | é o único item realmente difícil |

Ou seja: portar **não** é reescrever o produto, é escrever a terceira
implementação da camada nativa (macOS → Windows → Linux).

## Plano por fases

- **Fase 1, abrir** (horas): Electron Linux + `app.asar` + stubs dos módulos
  dispensáveis + `better-sqlite3` recompilado. Objetivo: janela abre, login
  funciona, notas aparecem. **Esta fase responde a pergunta que decide tudo:
  o backend aceita um cliente não-oficial?**
- **Fase 2, gravar** (semanas): implementar `granola.node` para Linux
  (captura de áudio via PipeWire) respeitando o contrato que o JS espera, 
  descoberto por engenharia reversa do bundle minificado.
- **Fase 3, diarização e extras**: `native/diarizer` e o que sobrar.

Riscos que podem invalidar o esforço mesmo com tudo funcionando: attestation
do cliente no backend, auto-update (Squirrel) sobrescrevendo os patches,
mudança de contrato a cada release, e os termos de uso do serviço.

## Requisitos

- Docker (todo o ambiente roda em container, **nada é instalado no host**)
- `p7zip` no host (para ler o `.dmg`)
- Uma cópia sua do `Granola - AI Notepad.dmg`

## Uso

```bash
# 1. extrai o .dmg para work/ (nada disso é versionado)
./scripts/extract.sh ~/Downloads/"Granola - AI Notepad.dmg"

# 2. mapeia os módulos nativos e o que cada um exige
./scripts/analyze.sh

# 3. constrói o ambiente Electron (container, não toca o host)
./scripts/build-env.sh

# 4. aplica os stubs e tenta subir a UI
./scripts/run.sh
```

## Estrutura

```
scripts/   extração, análise, build do container e execução
stubs/     nossos substitutos JS para os módulos nativos macOS
docs/      achados da engenharia reversa
work/      (ignorado) app extraído, sua cópia, não versionada
```

## Licença

Código deste repositório: MIT. Não se aplica ao Granola, que permanece
propriedade da Granola Labs, Inc.
