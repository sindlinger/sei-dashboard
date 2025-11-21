from __future__ import annotations

import argparse
import collections
import json
import logging
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from datasets import Dataset, load_dataset
import evaluate
from transformers import (
    AutoModelForQuestionAnswering,
    AutoTokenizer,
    Trainer,
    TrainingArguments,
    default_data_collator,
    set_seed,
    EarlyStoppingCallback,
)

def _resolve_eval_param_name() -> str | None:
    import inspect

    params = inspect.signature(TrainingArguments.__init__).parameters
    if "evaluation_strategy" in params:
        return "evaluation_strategy"
    if "eval_strategy" in params:
        return "eval_strategy"
    return None


LOGGER = logging.getLogger("train_qa")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Treina modelo de QA (span extraction) no dataset JSON/JSONL.")
    parser.add_argument("--train-file", required=True, help="Arquivo JSON/JSONL de treino (campos id/question/context/answers).")
    parser.add_argument("--validation-file", help="Arquivo JSON/JSONL de validação. Se omitido, usa split automático.")
    parser.add_argument("--validation-split", type=float, default=0.1, help="Proporção para split automático (default=0.1).")
    parser.add_argument("--model-name", default="deepset/xlm-roberta-large-squad2", help="Checkpoint base do Hugging Face.")
    parser.add_argument("--output-dir", required=True, help="Diretório de saída para o modelo treinado.")
    parser.add_argument("--num-epochs", type=int, default=3, help="Número de épocas.")
    parser.add_argument("--batch-size", type=int, default=4, help="Tamanho por device para treino.")
    parser.add_argument("--eval-batch-size", type=int, default=8, help="Tamanho por device na validação.")
    parser.add_argument("--learning-rate", type=float, default=3e-5, help="Taxa de aprendizado.")
    parser.add_argument("--weight-decay", type=float, default=0.01, help="Weight decay.")
    parser.add_argument("--warmup-ratio", type=float, default=0.0, help="Razão de warmup linear (0-1).")
    parser.add_argument("--gradient-accumulation", type=int, default=1, help="Steps de acumulação de gradientes.")
    parser.add_argument("--max-length", type=int, default=384, help="Comprimento máximo da sequência.")
    parser.add_argument("--doc-stride", type=int, default=128, help="Stride entre janelas para contextos longos.")
    parser.add_argument("--max-answer-length", type=int, default=80, help="Comprimento máximo permitido para respostas.")
    parser.add_argument("--n-best-size", type=int, default=20, help="Quantidade de candidatos por exemplo para pós-processamento.")
    parser.add_argument(
        "--null-score-diff-threshold",
        type=float,
        default=0.0,
        help="Threshold para respostas vazias (SQuAD v2).",
    )
    parser.add_argument(
        "--early-stopping-patience",
        type=int,
        help="Ativa early stopping após N avaliações sem melhora (default: desativado).",
    )
    parser.add_argument("--max-train-samples", type=int, help="Limita o número de exemplos de treino (debug).")
    parser.add_argument("--max-eval-samples", type=int, help="Limita o número de exemplos de validação (debug).")
    parser.add_argument("--seed", type=int, default=42, help="Seed global.")
    parser.add_argument("--fp16", action="store_true", help="Usa mixed precision FP16 (GPU).")
    parser.add_argument("--bf16", action="store_true", help="Usa mixed precision BF16 (GPU compatível).")
    parser.add_argument("--report-to", default="none", help="Backend de logging (wandb, tensorboard, none). Default=none.")
    parser.add_argument(
        "--logging-steps",
        type=int,
        default=50,
        help="Intervalo (steps) para logs de loss.",
    )
    return parser.parse_args()


def load_json_dataset(path: Path, split_name: str) -> Dataset:
    data_files = {split_name: str(path)}
    dataset_dict = load_dataset("json", data_files=data_files)
    return dataset_dict[split_name]


def has_impossible_answers(dataset: Dataset) -> bool:
    for answers in dataset["answers"]:
        texts = answers.get("text") if isinstance(answers, dict) else []
        if isinstance(texts, list) and len(texts) == 0:
            return True
    return False


def postprocess_qa_predictions(
    examples: Dataset,
    features: Dataset,
    predictions: Tuple[np.ndarray, np.ndarray],
    tokenizer: AutoTokenizer,
    n_best_size: int,
    max_answer_length: int,
    version_2_with_negative: bool,
    null_score_diff_threshold: float,
) -> Tuple[Dict[str, str], Dict[str, float]]:
    """Adaptado do script oficial run_qa.py da Hugging Face."""

    start_logits, end_logits = predictions
    example_id_to_index = {k: i for i, k in enumerate(examples["id"])}
    features_per_example = collections.defaultdict(list)
    for idx, feature in enumerate(features):
        features_per_example[example_id_to_index[feature["example_id"]]].append(idx)

    predictions_dict: Dict[str, str] = collections.OrderedDict()
    scores_diff_json: Dict[str, float] = collections.OrderedDict()

    for example_index, example in enumerate(examples):
        feature_indices = features_per_example.get(example_index, [])
        min_null_score = None
        valid_answers: List[Dict[str, float | str]] = []

        context = example["context"]

        for feature_index in feature_indices:
            start_logit = start_logits[feature_index]
            end_logit = end_logits[feature_index]
            offsets = features[feature_index]["offset_mapping"]
            input_ids = features[feature_index]["input_ids"]
            cls_index = input_ids.index(tokenizer.cls_token_id)

            if version_2_with_negative:
                feature_null_score = start_logit[cls_index] + end_logit[cls_index]
                if min_null_score is None or min_null_score > feature_null_score:
                    min_null_score = feature_null_score

            start_indexes = np.argsort(start_logit)[-1 : -n_best_size - 1 : -1].tolist()
            end_indexes = np.argsort(end_logit)[-1 : -n_best_size - 1 : -1].tolist()

            for start_index in start_indexes:
                for end_index in end_indexes:
                    if start_index >= len(offsets) or end_index >= len(offsets):
                        continue
                    if offsets[start_index] is None or offsets[end_index] is None:
                        continue
                    if end_index < start_index:
                        continue
                    length = end_index - start_index + 1
                    if length > max_answer_length:
                        continue
                    start_char = offsets[start_index][0]
                    end_char = offsets[end_index][1]
                    text = context[start_char:end_char]
                    score = start_logit[start_index] + end_logit[end_index]
                    valid_answers.append(
                        {
                            "score": score,
                            "text": text,
                            "start_logit": float(start_logit[start_index]),
                            "end_logit": float(end_logit[end_index]),
                        }
                    )

        if version_2_with_negative:
            valid_answers.append({"text": "", "score": min_null_score or 0.0, "start_logit": 0.0, "end_logit": 0.0})

        if valid_answers:
            best_answer = max(valid_answers, key=lambda x: x["score"])  # type: ignore[attr-defined]
        else:
            best_answer = {"text": "", "score": 0.0}

        if version_2_with_negative:
            score_diff = (min_null_score or 0.0) - best_answer["score"]
            scores_diff_json[example["id"]] = score_diff
            if score_diff > null_score_diff_threshold:
                predictions_dict[example["id"]] = ""
            else:
                predictions_dict[example["id"]] = best_answer["text"]
        else:
            predictions_dict[example["id"]] = best_answer["text"]

    return predictions_dict, scores_diff_json


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

    train_path = Path(args.train_file).expanduser()
    val_path = Path(args.validation_file).expanduser() if args.validation_file else None

    if not train_path.exists():
        raise SystemExit(f"Arquivo de treino não encontrado: {train_path}")
    if val_path and not val_path.exists():
        raise SystemExit(f"Arquivo de validação não encontrado: {val_path}")

    set_seed(args.seed)

    LOGGER.info("Carregando dataset de treino: %s", train_path)
    train_dataset = load_json_dataset(train_path, "train")
    if args.max_train_samples:
        train_dataset = train_dataset.select(range(min(args.max_train_samples, len(train_dataset))))

    if val_path:
        LOGGER.info("Carregando dataset de validação: %s", val_path)
        eval_dataset = load_json_dataset(val_path, "validation")
    else:
        split_ratio = args.validation_split
        if not 0.0 < split_ratio < 1.0:
            raise SystemExit("validation_split deve estar entre 0 e 1 quando não há arquivo de validação.")
        split = train_dataset.train_test_split(test_size=split_ratio, seed=args.seed)
        train_dataset = split["train"]
        eval_dataset = split["test"]

    if args.max_eval_samples:
        eval_dataset = eval_dataset.select(range(min(args.max_eval_samples, len(eval_dataset))))

    version_2_with_negative = has_impossible_answers(train_dataset) or has_impossible_answers(eval_dataset)

    tokenizer = AutoTokenizer.from_pretrained(args.model_name, use_fast=True)
    model = AutoModelForQuestionAnswering.from_pretrained(args.model_name)

    pad_on_right = tokenizer.padding_side == "right"

    def prepare_train_features(examples: Dict[str, List[str]]):
        tokenized_examples = tokenizer(
            examples["question" if pad_on_right else "context"],
            examples["context" if pad_on_right else "question"],
            truncation="only_second" if pad_on_right else "only_first",
            max_length=args.max_length,
            stride=args.doc_stride,
            return_overflowing_tokens=True,
            return_offsets_mapping=True,
            padding="max_length",
        )

        sample_mapping = tokenized_examples.pop("overflow_to_sample_mapping")
        offset_mapping = tokenized_examples.pop("offset_mapping")
        start_positions = []
        end_positions = []

        for i, offsets in enumerate(offset_mapping):
            input_ids = tokenized_examples["input_ids"][i]
            cls_index = input_ids.index(tokenizer.cls_token_id)
            sequence_ids = tokenized_examples.sequence_ids(i)
            sample_index = sample_mapping[i]
            answers = examples["answers"][sample_index]
            if len(answers["answer_start"]) == 0:
                start_positions.append(cls_index)
                end_positions.append(cls_index)
                continue
            start_char = answers["answer_start"][0]
            end_char = start_char + len(answers["text"][0])

            context_index = 1 if pad_on_right else 0
            token_start_index = 0
            while sequence_ids[token_start_index] != context_index:
                token_start_index += 1
            token_end_index = len(input_ids) - 1
            while sequence_ids[token_end_index] != context_index:
                token_end_index -= 1

            if not (offsets[token_start_index][0] <= start_char and offsets[token_end_index][1] >= end_char):
                start_positions.append(cls_index)
                end_positions.append(cls_index)
            else:
                while token_start_index < len(offsets) and offsets[token_start_index][0] <= start_char:
                    token_start_index += 1
                start_positions.append(token_start_index - 1)
                while offsets[token_end_index][1] >= end_char:
                    token_end_index -= 1
                end_positions.append(token_end_index + 1)

        tokenized_examples["start_positions"] = start_positions
        tokenized_examples["end_positions"] = end_positions
        return tokenized_examples

    def prepare_validation_features(examples: Dict[str, List[str]]):
        tokenized_examples = tokenizer(
            examples["question" if pad_on_right else "context"],
            examples["context" if pad_on_right else "question"],
            truncation="only_second" if pad_on_right else "only_first",
            max_length=args.max_length,
            stride=args.doc_stride,
            return_overflowing_tokens=True,
            return_offsets_mapping=True,
            padding="max_length",
        )

        sample_mapping = tokenized_examples.pop("overflow_to_sample_mapping")
        tokenized_examples["example_id"] = []
        tokenized_examples["start_positions"] = []
        tokenized_examples["end_positions"] = []

        for i in range(len(tokenized_examples["input_ids"])):
            sequence_ids = tokenized_examples.sequence_ids(i)
            context_index = 1 if pad_on_right else 0
            input_ids = tokenized_examples["input_ids"][i]
            sample_index = sample_mapping[i]
            tokenized_examples["example_id"].append(examples["id"][sample_index])

            offset = tokenized_examples["offset_mapping"][i]
            answers = examples["answers"][sample_index]
            if len(answers["answer_start"]) == 0:
                start_positions = input_ids.index(tokenizer.cls_token_id)
                end_positions = start_positions
            else:
                start_char = answers["answer_start"][0]
                end_char = start_char + len(answers["text"][0])
                token_start_index = 0
                while sequence_ids[token_start_index] != context_index:
                    token_start_index += 1
                token_end_index = len(input_ids) - 1
                while sequence_ids[token_end_index] != context_index:
                    token_end_index -= 1
                if not (offset[token_start_index][0] <= start_char and offset[token_end_index][1] >= end_char):
                    start_positions = input_ids.index(tokenizer.cls_token_id)
                    end_positions = start_positions
                else:
                    while token_start_index < len(offset) and offset[token_start_index][0] <= start_char:
                        token_start_index += 1
                    start_positions = token_start_index - 1
                    while offset[token_end_index][1] >= end_char:
                        token_end_index -= 1
                    end_positions = token_end_index + 1

            tokenized_examples["start_positions"].append(start_positions)
            tokenized_examples["end_positions"].append(end_positions)
            tokenized_examples["offset_mapping"][i] = [
                o if sequence_ids[k] == context_index else None for k, o in enumerate(offset)
            ]
        return tokenized_examples

    LOGGER.info("Tokenizando datasets...")
    train_dataset = train_dataset.map(
        prepare_train_features,
        batched=True,
        remove_columns=train_dataset.column_names,
    )

    eval_examples = eval_dataset
    eval_features = eval_examples.map(
        prepare_validation_features,
        batched=True,
        remove_columns=eval_examples.column_names,
    )

    eval_dataset = eval_features.remove_columns(["offset_mapping", "example_id"])

    training_kwargs = dict(
        output_dir=str(Path(args.output_dir)),
        save_strategy="epoch",
        learning_rate=args.learning_rate,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.eval_batch_size,
        num_train_epochs=args.num_epochs,
        weight_decay=args.weight_decay,
        warmup_ratio=args.warmup_ratio,
        gradient_accumulation_steps=args.gradient_accumulation,
        fp16=args.fp16,
        bf16=args.bf16,
        logging_steps=args.logging_steps,
        report_to=args.report_to,
        save_total_limit=2,
        load_best_model_at_end=True,
    )
    if args.early_stopping_patience and args.early_stopping_patience > 0:
        training_kwargs["metric_for_best_model"] = "eval_loss"
        training_kwargs["greater_is_better"] = False
    eval_param = _resolve_eval_param_name()
    if eval_param:
        training_kwargs[eval_param] = "epoch"
    else:
        LOGGER.warning("TrainingArguments não expõe parâmetro evaluation_strategy / eval_strategy; usando default.")

    training_args = TrainingArguments(**training_kwargs)

    callbacks = []
    if args.early_stopping_patience and args.early_stopping_patience > 0:
        callbacks.append(
            EarlyStoppingCallback(
                early_stopping_patience=args.early_stopping_patience,
            )
        )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        tokenizer=tokenizer,
        data_collator=default_data_collator,
        callbacks=callbacks,
    )

    trainer.train()
    trainer.save_state()
    trainer.save_model()

    LOGGER.info("Modelo salvo em %s", training_args.output_dir)

    LOGGER.info("Executando avaliação final (EM/F1)...")
    predictions = trainer.predict(eval_dataset)
    formatted_predictions, scores_diff = postprocess_qa_predictions(
        eval_examples,
        eval_features,
        predictions.predictions,
        tokenizer,
        args.n_best_size,
        args.max_answer_length,
        version_2_with_negative,
        args.null_score_diff_threshold,
    )

    metric = evaluate.load("squad_v2" if version_2_with_negative else "squad")
    references = [{"id": ex["id"], "answers": ex["answers"]} for ex in eval_examples]
    squad_predictions = []
    for qid, answer in formatted_predictions.items():
        entry = {"id": qid, "prediction_text": answer}
        if version_2_with_negative:
            entry["no_answer_probability"] = float(scores_diff.get(qid, 0.0))
        squad_predictions.append(entry)

    metrics = metric.compute(predictions=squad_predictions, references=references)
    LOGGER.info("Métricas SQuAD: %s", json.dumps(metrics, ensure_ascii=False))

    metrics_path = Path(training_args.output_dir) / "metrics-final.json"
    metrics_path.write_text(json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8")
    LOGGER.info("Métricas salvas em %s", metrics_path)


if __name__ == "__main__":
    main()
