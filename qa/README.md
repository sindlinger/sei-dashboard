# sei-qa-xlm (teste rápido GPU)

## Passos

1) Criar venv com uv e instalar Torch + deps (CUDA 12.1 wheel, compatível com seu driver CUDA 13):
```bash
mkdir -p /mnt/b/dev/sei-qa-xlm
cd /mnt/b/dev/sei-qa-xlm
uv venv .venv
source .venv/bin/activate
uv pip install --extra-index-url https://download.pytorch.org/whl/cu121 \
  torch==2.2.2+cu121 transformers==4.46.3 datasets==2.19.1 evaluate==0.4.1
```

2) Testar GPU:
```bash
source .venv/bin/activate
python test_torch_gpu.py
```

3) Testar modelo XLM-R large QA:
```bash
source .venv/bin/activate
python - <<'PY'
from transformers import pipeline
qa = pipeline(
    "question-answering",
    model="deepset/xlm-roberta-large-squad2",
    tokenizer="deepset/xlm-roberta-large-squad2",
    device=0  # use -1 para CPU
)
context = "O número do processo é 0800237-72.2021.8.15.0001 e o perito é João."
print(qa(question="Qual o número do processo?", context=context))
PY
```

Se `torch.cuda.is_available()` for False ou der erro de CUDA, reinstale a versão CPU:
```bash
uv pip install --extra-index-url https://download.pytorch.org/whl/cpu \
  torch==2.2.2+cpu --force-reinstall
```
E no pipeline defina `device=-1`.

## Dataset para treino

- O script espera JSON ou JSONL com campos `id`, `context`, `question` e `answers`.
- `answers` aceita tanto uma lista de objetos (`{"text": "...", "start": N}`) quanto o formato SQuAD clássico (`{"text": [...], "answer_start": [...]}`).
- Exemplos vazios (`"answers": []`) indicam perguntas sem resposta explícita no texto.
- Use `sample_dataset.jsonl` como referência rápida ou gere direto dos ZIPs (abaixo).

### Gerar dataset a partir dos ZIPs do SEI

`build_dataset.py` reaproveita o extrator offline e monta perguntas/respostas reais usando os documentos já baixados:

```bash
cd qa
source .venv/bin/activate
PYTHONPATH=.. python build_dataset.py \
  --zip-dir ../playwright-downloads \
  --output dataset-pericias.jsonl \
  --limit 50 \
  --window 250
```

Notas:
- `--fields` limita os campos usados (default cobre Processo, Partes, Perito, Especialidade, Espécie, Fator, Valores, Datas etc).
- `--limit` ajuda a gerar amostras menores; remova para varrer toda a pasta.
- O script ignora campos sem valor ou cujo texto não é encontrado no documento; use `--allow-empty` para registrar perguntas sem resposta explícita.
- Cada exemplo recebe `metadata` com nome do ZIP/arquivo fonte para facilitar auditoria.

## Seleção de contextos (inferência QA)

- `qa/context_selector.py` reúne as mesmas âncoras do extrator e produz janelas curtas (±260 caracteres) por campo, com offset e score. Isso evita rodar o QA em páginas inteiras.
- Para auditar os trechos escolhidos, use `preview_contexts.py`:
  ```bash
  cd /mnt/b/dev/sei-dashboard/ml
  PYTHONPATH=.. python ../qa/preview_contexts.py \
    --zip ../playwright-downloads/000219_17_2025_8_15_SEI_000219_17.2025.8.15.zip \
    --fields PROMOVENTE PROMOVIDO PERITO \
    --max-per-field 2
  ```
  O utilitário imprime (e opcionalmente salva via `--json-output`) os trechos por campo, já ordenados pela pontuação. Na fase de inferência final, basta reaproveitar `select_contexts()` para alimentar o modelo apenas com esses recortes priorizados.

### Executar QA diretamente sobre os contextos

```bash
cd /mnt/b/dev/sei-dashboard/ml
PYTHONPATH=.. python ../qa/run_context_qa.py \
  --zip ../playwright-downloads/000219_17_2025_8_15_SEI_000219_17.2025.8.15.zip \
  --model-name models/qa-xlm \
  --fields PROMOVENTE PROMOVIDO PERITO \
  --max-per-field 3 \
  --min-score 0.25 \
  --device 0 \
  --output qa_results.json
```

- Troque `--zip` por `--zip-dir` para processar lotes (use `--limit` para recortes). O script imprime o melhor span acima do limiar por campo e salva todos os candidatos/offsets no JSON indicado.

## Treinar (fine-tune) o XLM-R QA

1) Ajuste/monte seu dataset (treino + validação) seguindo o formato acima.
2) Rode o script de treino:
```bash
cd qa
source .venv/bin/activate  # ou outro ambiente com transformers/datasets instalados
python train_qa.py \
  --train-file sample_dataset.jsonl \
  --output-dir modelo-qa \
  --num-epochs 3 \
  --batch-size 4 \
  --fp16
```

Parâmetros úteis:
- `--validation-file caminho.jsonl` usa um arquivo separado de validação.
- Sem `--validation-file`, o script separa automaticamente 10% do treino (`--validation-split`).
- `--model-name` permite trocar o checkpoint base.
- `--max-length`/`--doc-stride` controlam o recorte dos contextos grandes.

Saídas:
- Pesos ajustados em `modelo-qa/` (pasta com `config.json`, `pytorch_model.bin`, tokenizer etc.).
- Log do Trainer com perda de treino e validação (quando existir).

> Observação: o script usa o `Trainer` padrão (com loss de QA). Para métricas de exatidão/F1 em estilo SQuAD, adapte conforme necessário ou use o script oficial `run_qa.py` da Hugging Face adicionando `post_process_function`.

## Avaliar (EM/F1) rapidamente

`eval_qa.py` executa o pipeline de QA no dataset e calcula `exact match` / `F1` usando o métrico oficial do SQuAD:

```bash
cd qa
source .venv/bin/activate
python eval_qa.py \
  --dataset dataset-pericias.jsonl \
  --model-name modelos/qa-xlm \
  --device 0 \
  --batch-size 8 \
  --limit 100
```

- `--device`: use `0` para GPU, `-1` para CPU.
- `--limit`: útil para uma checagem rápida (remova para avaliar tudo).
- Saída final inclui log resumido (`EM=.. | F1=..`) e o JSON com ambas as métricas.
