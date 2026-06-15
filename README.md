# Leve Pátio

App Flutter **offline-first** para a operação de pátio da Leve Mobilidade: controle de
entrada/saída de veículos, emissão de tickets, cálculo de tarifa, caixa (abertura,
movimentos, fechamento) e impressão térmica Bluetooth — funcionando mesmo sem internet
e sincronizando com o **Leve ERP** quando a conexão volta.

> Documento de contexto e relação detalhada com o ERP: [`docs/CONTEXTO-ERP.md`](docs/CONTEXTO-ERP.md)

## Stack

| Camada | Tecnologia |
|---|---|
| UI | Flutter 3.44+ / Dart 3.12+ |
| Estado | Riverpod 3 |
| Navegação | go_router 17 |
| Persistência local | **Drift** (SQLite) — banco offline-first |
| Rede | Dio 5 + interceptors de Bearer/refresh |
| Impressão | `print_bluetooth_thermal` (ESC/POS) |
| Compartilhado | pacote local `leve_core` (em [`packages/leve_core`](packages/leve_core)) |

## Arquitetura

```
lib/
  core/
    config/env.dart          → API_BASE_URL, namespaces /api/mobile/v1/patio/*
    di/providers.dart        → Providers Riverpod globais
    network/                 → patio_api_client + bearer/refresh interceptors
    router/app_router.dart   → go_router + guard de auth
    theme/                   → paleta e tema do Pátio
    widgets/                 → Glass, background, bottom nav, status bar
  database/
    tables/                  → tabelas Drift (tickets, caixa, clientes, tarifas, sync_log…)
    daos/                    → DAOs (tickets, caixa, operacao, clientes, sync)
  features/
    auth/        → login (Bearer token + refresh) e app-config
    home/        → dashboard da operação
    patio/       → veículos no pátio
    tickets/     → emissão e consulta de tickets
    tarifa/      → cálculo de tarifa
    operacao/    → fluxo de entrada/saída
    caixa/       → abertura, movimentos e fechamento de caixa
    printer/ + printing/ → descoberta de impressora e layout ESC/POS
    sync/        → fila de sincronização com o ERP
    ajustes/     → perfil, impressora, diagnóstico, logout
```

### Offline-first
Toda escrita acontece primeiro no banco **Drift** local e entra na fila de
`sync_log`. Um worker reenvia as mudanças ao ERP (`/sync`) a cada ~5 min ou sob
demanda, com até 10 tentativas. A leitura inicial vem do `/bootstrap`. Assim a
operação de pátio nunca para por falta de rede.

### Autenticação
Diferente dos outros apps Leve (que usam cookie/NextAuth), o Pátio usa **Bearer
token** por dispositivo, com refresh automático via `refresh_interceptor`. O token
fica no `flutter_secure_storage`.

## Pré-requisitos

- Flutter SDK 3.44+ (Dart 3.12+)
- Android SDK (build/run Android)

## Setup

```bash
flutter pub get          # resolve deps, incl. leve_core em packages/
dart run build_runner build --delete-conflicting-outputs   # gera código do Drift
```

## Rodar (debug)

```bash
flutter run --dart-define=API_BASE_URL=https://dashboard.levemobilidade.com.br
```

## Build APK (release)

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://dashboard.levemobilidade.com.br \
  --dart-define=APP_VERSION=1.0.0 \
  --dart-define=BUILD_NUMBER=1
# APK em: build/app/outputs/flutter-apk/app-release.apk
```

## Variáveis de build (`--dart-define`)

| Var | Default | Descrição |
|---|---|---|
| `API_BASE_URL` | `https://dashboard.levemobilidade.com.br` | URL do Leve ERP |
| `APP_ID` | `patio` | Identifica o app na rota `app-config` |
| `HTTP_LOGS` | `true` | Liga logs HTTP do Dio |
| `APP_VERSION` | `1.0.0` | Versão semântica |
| `BUILD_NUMBER` | `0` | Número do build |
| `GIT_SHA` | `dev` | Hash curto do commit |

## Pacote `leve_core`

Componentes compartilhados entre os apps Flutter da Leve (cliente HTTP base,
secure storage, toast, skeleton, empty state). Vendorizado em
[`packages/leve_core`](packages/leve_core) para o repositório clonar e compilar
de forma autônoma.
