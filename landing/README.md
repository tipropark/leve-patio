# Landing Page — Leve Pátio

Página de **venda interna** do app Leve Pátio para a **diretoria da Leve Mobilidade**.
Não é marketing para cliente externo: o objetivo é apresentar o valor de negócio do app
(receita protegida, caixa auditável, redução de passivo, custo baixo) e levar a uma
demonstração ao vivo com a TI.

## URL de produção

**https://dashboard.levemobilidade.com.br/apps/patio/**

Servida **estaticamente pelo nginx** da VPS (fora do Next/ERP):

- Arquivo no servidor: `/var/www/leve-apps/patio/index.html`
- Bloco no nginx (`/etc/nginx/sites-enabled/default`, antes do `location /`):
  ```nginx
  location /apps/ {
      alias /var/www/leve-apps/;
      index index.html;
      try_files $uri $uri/ =404;
  }
  ```
- Backup do config anterior: `/root/nginx-default.bak-*`

## Como atualizar

Edite `landing/index.html` e envie o arquivo — **sem build, sem pm2, sem reload do nginx**:

```bash
scp -i ~/.ssh/id_ed25519 landing/index.html \
  root@dashboard.levemobilidade.com.br:/var/www/leve-apps/patio/index.html
```

## Arquitetura da página

Arquivo único auto-contido: HTML + CSS + JS inline. Única dependência externa é o
Google Fonts (Archivo / Archivo Black / JetBrains Mono).

### Direção de design
- **Estética:** industrial/utilitária ("sinalização de pátio")
- **Cores:** navy asfalto `#011230` (fundo, = `AppPatioColors.background` do app) +
  vermelho da logomarca `#E30613` (= `AppPatioColors.secondary`) + verde/laranja de sync
- **Tipografia:** Archivo Black (display, caixa alta) · Archivo (corpo) · JetBrains Mono (placas, números, tags)
- **Âncoras visuais:** ticket térmico com bordas picotadas flutuando ao lado do phone mockup;
  placa Mercosul desenhada em CSS; faixa hachurada de sinalização; marquee "SEM SINAL, SEM PROBLEMA"

### Seções (ordem)
1. Hero — tese "O pátio não para. Nem sem internet." + mockup entrada com OCR + ticket
2. `#valor` — **Para a diretoria** (6 cards de impacto no negócio)
3. `#offline` — fluxo offline-first em 4 passos (Drift → fila → sync ~5min → ERP)
4. `#recursos` — 6 recursos operacionais
5. `#ocr` — spotlight da leitura de placa (demo animada com linha de scan)
6. `#telas` — 3 mockups de telas (home, pátio, fechamento) desenhados em CSS/SVG
7. `#specs` — ficha técnica honesta (Flutter, Drift, Bearer, ML Kit, ESC/POS, Stone opcional)
8. `#demo` — CTA "Agendar demonstração · ti@leve.mobi"
9. `#apps` — links cruzados para as outras landings (`/apps/mobile/`, `/apps/clientes/`)

### Convenções
- CTAs sempre "agendar demonstração" (distribuição é interna, não há loja/instalação pública)
- Nenhuma estatística inventada: os únicos números afirmados são fatos técnicos reais
  (sync ~5 min, 10 retentativas, OCR on-device); valores nos mockups são dados de exemplo
- Acessibilidade: touch targets ≥48px, `prefers-reduced-motion`, foco visível, ARIA nos mockups
- Scroll-reveal via IntersectionObserver (classe `.reveal`)

## Pendências
- Trocar os mockups CSS por screenshots reais do app quando houver (basta substituir o
  conteúdo interno das molduras `.phone` por `<img>`)

## Páginas irmãs
- Leve Mobile: `projeto-android-leveERP/landing/index.html` → `/apps/mobile/`
- Leve Clientes: `projeto-android-leveClientes/landing/index.html` → `/apps/clientes/`

Documentação central da infraestrutura: `leve-erp/docs/LeveERP_Paginas-Estaticas-Publicas.md`
