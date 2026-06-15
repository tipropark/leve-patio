# Leve Pátio × Leve ERP — Documento de Contexto

> Última atualização: 2026-06-15

## 1. Visão geral

O **Leve Pátio** é o aplicativo de operação de pátio (estacionamento / pátio de
veículos) da Leve Mobilidade. Ele é um **cliente do Leve ERP**: toda a regra de
negócio, cadastro e consolidação financeira vivem no ERP. O app existe para que o
operador no pátio consiga trabalhar **mesmo sem internet** e sincronizar depois.

- **Leve ERP** (`dashboard.levemobilidade.com.br`): Next.js + Supabase. Fonte da
  verdade — clientes, planos, tarifas, caixa consolidado, relatórios.
- **Leve Pátio** (este repo): Flutter, offline-first. Captura a operação no chão
  do pátio e envia ao ERP.

```
┌──────────────────────┐         HTTPS / Bearer          ┌──────────────────────┐
│      Leve Pátio       │  ──────────────────────────────▶ │       Leve ERP        │
│  (Flutter, offline)   │   /api/mobile/v1/patio/*         │ (Next.js + Supabase)  │
│  Drift/SQLite local   │ ◀──────────────────────────────  │   fonte da verdade    │
└──────────────────────┘   bootstrap / sync / app-config   └──────────────────────┘
```

## 2. Por que offline-first

A operação de pátio não pode parar quando a rede cai (guarita, subsolo, 4G
instável). Por isso:

1. **Toda escrita** (entrada de veículo, ticket, movimento de caixa) é gravada
   primeiro no **banco Drift (SQLite) local**.
2. A mudança entra numa **fila de sincronização** (`sync_log`).
3. Um worker envia o lote ao ERP via `/sync` (a cada ~5 min ou sob demanda),
   com até **10 tentativas**.
4. Na inicialização, o app puxa o estado consolidado via `/bootstrap`.

O ERP é sempre a autoridade final; em conflito, vence o ERP.

## 3. Endpoints consumidos no ERP

Namespace base: **`/api/mobile/v1/patio`** (definido em [`lib/core/config/env.dart`](../lib/core/config/env.dart)).

| Função | Endpoint |
|---|---|
| Login / refresh de token | `/api/mobile/v1/patio/auth`, `/api/mobile/v1/patio/auth/refresh` |
| Configuração do app por dispositivo | `/api/mobile/v1/patio/app-config?app_id=patio` |
| Carga inicial (estado consolidado) | `/api/mobile/v1/patio/bootstrap` |
| Sincronização das mudanças locais | `/api/mobile/v1/patio/sync` |
| Registro/identificação do dispositivo | `/api/mobile/v1/patio/dispositivo`, `/api/mobile/v1/patio/dispositivo/info` |

> Qualquer mudança de contrato nesses endpoints deve ser feita **no ERP**
> (`c:\VibeCoding\leve-erp`, rotas `src/app/api/mobile/v1/patio/*`) e refletida
> aqui apenas no consumo.

## 4. Autenticação — diferente dos outros apps Leve

| App | Mecanismo |
|---|---|
| Leve Mobile (colaboradores) | Cookie de sessão (NextAuth v5) |
| Leve Gestão (diretoria) | Cookie de sessão (NextAuth v5) |
| **Leve Pátio (este)** | **Bearer token por dispositivo + refresh automático** |

O Pátio roda em dispositivos fixos da guarita, então usa token de longa duração
guardado no `flutter_secure_storage`, renovado pelo `refresh_interceptor` quando
expira. Ver [`lib/core/network/`](../lib/core/network/).

## 5. Domínios sincronizados

Tabelas Drift locais (em [`lib/database/tables`](../lib/database/tables)) e o que
representam no ERP:

| Local (Drift) | Domínio | Origem da verdade |
|---|---|---|
| `tickets_table` | Tickets de entrada/saída | ERP (consolida faturamento) |
| `patio_clientes_table` / `patio_cliente_placas_table` | Clientes e placas (mensalistas/planos) | ERP |
| `tarifas_table` | Tabela de tarifas | ERP (espelhada localmente p/ cálculo offline) |
| `caixa_sessoes_table` / `caixa_movimentos_table` | Abertura/fechamento e movimentos de caixa | ERP (conciliação financeira) |
| `operacao_cache_table` | Cache do estado de operação | derivado |
| `sync_log_table` | Fila de mudanças pendentes de envio | só local |

## 6. Relação com a feature E-Park / Clientes-Planos

O ERP tem o módulo **E-Park** (clientes + planos de livre passagem). O Pátio
**reconhece** esses clientes/planos: ao ler a placa, consulta a base local
(sincronizada do ERP) para decidir se é livre passagem (mensalista) ou avulso, e
aplica a tarifa correta — tudo offline. A definição de planos/preços é feita no
ERP; o Pátio só consome e aplica.

## 7. Pacote compartilhado `leve_core`

`leve_core` reúne componentes comuns dos apps Flutter da Leve (cliente HTTP base,
secure storage, toasts, skeleton, empty state). Está **vendorizado** em
[`packages/leve_core`](../packages/leve_core) para o repositório ser clonável e
compilável de forma autônoma (originalmente era um path `../leve_core` no
monorepo local de desenvolvimento).

## 8. Fluxo de build e deploy

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://dashboard.levemobilidade.com.br \
  --dart-define=APP_VERSION=1.0.0 \
  --dart-define=BUILD_NUMBER=<n>
```

Atenção de ambiente: em máquinas com pouca RAM, ajustar
`android/gradle.properties` (`-Xmx3G`) para evitar OOM do daemon Gradle no
`assembleRelease`.

## 9. Resumo das fronteiras

- **No ERP:** regras de negócio, cadastros, planos/tarifas, conciliação
  financeira, relatórios.
- **No Pátio:** captura da operação no chão, cálculo de tarifa offline, emissão
  de ticket, impressão térmica, fila e envio de sincronização.
- **Regra de ouro:** em conflito de dados, o **ERP vence**.
