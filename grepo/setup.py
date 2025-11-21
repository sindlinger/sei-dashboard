from setuptools import setup, find_packages
"""
 Configurar
grepo config set user sindlinger
grepo config set token seu-token-aqui

# Ver configurações
grepo config get user
grepo config get token
grepo config  # mostra tudo

# Criar repositório
grepo create meu-repo
grepo create outro-repo --private
grepo create repo --local ./path

# Remover configurações
grepo config unset token
grepo config unset --all
"""
setup(
    name="grepo",
    version="1.4.3",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[
        "requests>=2.25.0",
        "python-dotenv>=0.19.0",
    ],
    entry_points={
        "console_scripts": [
            "grepo=grepo.cli:main",
        ],
    },
    author="Eduado Candeia Gonçalves",
    author_email="candeia.goncalves@gmail.com",
    description="Uma ferramenta CLI para criar e gerenciar repositórios GitHub",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    keywords="github, git, cli, repository",
    url="https://github.com/sindlinger/grepo",
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
    ],
    python_requires=">=3.6",
)