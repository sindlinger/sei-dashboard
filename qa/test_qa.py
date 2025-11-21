from transformers import pipeline
qa = pipeline(
    "question-answering",
    model="deepset/xlm-roberta-large-squad2",
    tokenizer="deepset/xlm-roberta-large-squad2",
    device=0  # use -1 para CPU
)
context = "O número do processo é 0800237-72.2021.8.15.0001 e o perito é João."
print(qa(question="Qual o número do processo?", context=context))
