# Release manual (o que o pipeline do M5 vai substituir)

Cronometre cada passo e anote os minutos em [toil-steps.csv](toil-steps.csv) (coluna `minutes`).
O exemplo sobe a versão **1.0.0 → 1.1.0** da `cell-a`, depois da `cell-b` e da `cell-c`.

> Para a demo você executa este roteiro uma vez, na frente da turma. Os tempos do CSV já vêm com valores
> típicos; troque pelos seus se medir.

## 1. Abrir sessão na EC2 (pelo navegador)
Console AWS → **Systems Manager → Session Manager → Start session** → selecione a instância `sre-demo` → **Start session**.
Depois, no terminal que abrir:
```bash
sudo -i
cd /opt/lab/demo-slo-pipeline
```

## 2. Atualizar o código
```bash
git -C /opt/lab pull --ff-only
```

## 3. Editar a versão
```bash
sed -i 's/"version": "1.0.0"/"version": "1.1.0"/' app/config.json
```

## 4. Construir a imagem
```bash
docker build -t sre-demo/cell-app:1.1.0 app/
```

## 5. Subir a cell-a e conferir
```bash
sed -i 's/^CELL_A_VERSION=.*/CELL_A_VERSION=1.1.0/' .env
docker compose --env-file .env up -d --no-build --no-deps cell-a
curl -s http://127.0.0.1:8001/health
```

## 6. Observar o canário
Neste ponto da aula **o dashboard ainda não existe** (ele é criado no M4). Use o **Metrics Explorer** do Datadog
(*Metrics → Explorer*) e espere alguns minutos olhando o SLI da `cell-a` na versão nova:

1. Consulta **a:** métrica `sre.requests.good`, filtro `cell:cell-a`, `sum by` → `version`.
2. Consulta **b:** métrica `sre.requests.total`, filtro `cell:cell-a`, `sum by` → `version`.
3. Fórmula: `a / b * 100`. Se a tela não mostrar o campo de fórmula, use *Advanced...* e escreva as consultas
   `sum:sre.requests.good{cell:cell-a} by {version}.as_count()` e `sum:sre.requests.total{cell:cell-a} by {version}.as_count()`.

A linha da `1.1.0` aparece ~1 a 2 min depois do deploy (atraso normal do Datadog). Esse é o gesto manual de "olhar o gráfico
e decidir" que o gate do M5 vai substituir.

> Alternativa: rode `create-dashboard` (ação do `demo-ops`) **antes** do M3, já que os SLOs do M2 existem. O dashboard se chama
> **"SRE Demo - Células e SLOs"** (*Dashboards → Dashboard List*) e o gráfico é *"Requisições por célula e versão"* mais
> *"Sucesso por célula (%)"*. Mas então o M4 deixa de "revelar" o dashboard como novidade.

## 7. Repetir para as outras células
```bash
sed -i 's/^CELL_B_VERSION=.*/CELL_B_VERSION=1.1.0/' .env
docker compose --env-file .env up -d --no-build --no-deps cell-b
curl -s http://127.0.0.1:8002/health

sed -i 's/^CELL_C_VERSION=.*/CELL_C_VERSION=1.1.0/' .env
docker compose --env-file .env up -d --no-build --no-deps cell-c
curl -s http://127.0.0.1:8003/health
```

## 8. Fechar o release
Decidir "no olho" se o SLO permitia soltar, avisar o time no chat e registrar o release no changelog.

---

Depois do release manual, rode a análise: GitHub → **Actions → demo-ops → Run workflow → action: `toil-roi`**
(ou, na própria sessão da EC2: `python3 m3-toil/toil_roi.py --releases 8 --automation-hours 16`).

Para voltar ao estado inicial (as versões voltam a 1.0.0), use a ação `reset` do `demo-ops` (o M5 cuida das versões).
