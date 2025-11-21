# GRepo - GitHub Repository Manager

Uma ferramenta CLI simples e eficiente para criar repositórios GitHub a partir de diretórios locais.

## Instalação

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/grepo.git

# Entre no diretório
cd grepo

# Instale em modo desenvolvimento
pip install -e .
```

## Uso

### Criar um novo repositório

```bash
# Usando o diretório atual
grepo create -n nome-do-repo -u seu-usuario-github -t seu-token

# Especificando um diretório diferente
grepo create -n nome-do-repo -u seu-usuario-github -t seu-token -l /caminho/do/projeto

# Criando um repositório privado
grepo create -n nome-do-repo -u seu-usuario-github -t seu-token -p
```

### Opções disponíveis

- `-n, --name`: Nome do repositório a ser criado (obrigatório)
- `-u, --user`: Nome do usuário no GitHub (obrigatório)
- `-t, --token`: Token do GitHub (opcional se definido no .env)
- `-l, --local`: Caminho do diretório local (default: diretório atual)
- `-p, --private`: Cria um repositório privado

### Usando token via arquivo .env

Crie um arquivo `.env` no diretório do projeto:
```
GITHUB_TOKEN=seu-token-aqui
```

## Desenvolvimento

O projeto usa uma estrutura Python moderna:
```
grepo/
├── src/
│   └── grepo/
│       ├── __init__.py
│       ├── __main__.py
│       ├── cli.py
│       └── core.py
├── setup.py
└── README.md
```

## Requisitos

- Python >= 3.6
- requests
- python-dotenv

## Autor

- Eduardo Candeia Gonçalves - [@sindlinger](https://github.com/sindlinger)

## Licença

MIT