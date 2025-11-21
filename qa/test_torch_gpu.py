import torch
print("torch:", torch.__version__)
print("CUDA disponível?", torch.cuda.is_available())
if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))
    x = torch.randn(1024, 1024, device="cuda")
    y = torch.mm(x, x)
    print("Teste mm ok, shape:", y.shape)
else:
    print("CUDA indisponível; teste rodou em CPU.")
