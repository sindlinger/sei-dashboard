# Estrutura ML

- `datasets/`: JSONL e bases derivadas do SEI (ex.: `dataset-full.jsonl`).
- `models/`: checkpoints finetunados com `qa/train_qa.py`.
- `logs/`: métricas adicionais ou saídas de testes.
- `artifacts/`: configs auxiliares, tokenizer extraídos, etc.
- `.venv/`: ambiente Python 3.11 com Torch/Transformers (ativado manualmente pelo usuário).

## Dependências

1. Instale o PyTorch compatível com sua GPU (ex.: cu121) **antes** das demais libs:
   ```bash
   cd /mnt/b/dev/sei-dashboard/ml
   source .venv/bin/activate
   uv pip install --extra-index-url https://download.pytorch.org/whl/cu121 \
     torch==2.2.2+cu121
   ```

2. Depois, instale os pacotes auxiliares do QA de uma vez só:
   ```bash
   uv pip install -r ml/requirements.txt
   ```
   (mantendo o ambiente ativado). Isso cobre `transformers`, `datasets`, `evaluate`, `accelerate`, `sentencepiece`, `protobuf` e `tiktoken` com as versões usadas nos scripts.

## Fluxo rápido

1. **Ativar ambiente**
   ```bash
   cd /mnt/b/dev/sei-dashboard/ml
   source .venv/bin/activate
   ```

2. **Gerar dataset (se necessário)** – usa o extrator offline e salva em `datasets/`:
   ```bash
   PYTHONPATH=.. python ../qa/build_dataset.py \
     --zip-dir ../playwright-downloads \
     --output datasets/dataset-full.jsonl \
     --window 250 \
     --workers 8
   ```

3. **Treinar (GPU)** – modelo base `deepset/xlm-roberta-large-squad2`, salvando em `models/qa-xlm`:
   ```bash
   PYTHONPATH=.. python ../qa/train_qa.py \
     --train-file datasets/dataset-full.jsonl \
     --output-dir models/qa-xlm \
     --num-epochs 3 \
     --batch-size 4 \
     --eval-batch-size 8 \
     --learning-rate 3e-5 \
     --fp16 \
     --early-stopping-patience 2
   ```
   Ajuste `--validation-file` ou `--validation-split` conforme o particionamento desejado. Logs com loss/Epoch ficam no console e o resumo EM/F1 é gravado em `models/qa-xlm/metrics-final.json`.

4. **Avaliar** – reutiliza o script dedicado para métricas detalhadas:
   ```bash
   PYTHONPATH=.. python ../qa/eval_qa.py \
     --dataset datasets/dataset-full.jsonl \
     --model-name models/qa-xlm \
     --device 0 \
     --batch-size 8
   ```

5. **Desativar ambiente**
   ```bash
   deactivate
   ```

> **Importante:** o usuário executa todos os comandos GPU manualmente. A automação apenas organiza os arquivos e scripts.

> **Espaço em disco:** cada checkpoint parcial ocupa ~2 GB (pesos + otimizador). Garanta espaço livre em `models/` antes de treinar; caso contrário o PyTorch lança erros `PytorchStreamWriter failed writing file data/...` ao salvar.
