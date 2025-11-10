"""
Interface de linha de comando no estilo Git para o GRepo.
"""

import os
import sys
import argparse
from typing import Optional, Sequence
from pathlib import Path

from .core import GitHubRepo
from .config import (
    set_config, get_config, unset_config, show_config,
    get_required_config
)

def create_cmd(args: argparse.Namespace) -> None:
    """
    Manipula o comando 'create'.
    Similar ao 'git init' + configuração remota.
    """
    try:
        # Obter configurações necessárias
        token = get_required_config('token')
        user = get_required_config('user')
        
        # Validar caminho local
        local_path = os.path.abspath(args.local)
        if not os.path.exists(local_path):
            raise ValueError(f"Diretório '{local_path}' não existe!")

        # Criar repositório
        print(f"\nCriando repositório '{args.name}'...")
        repo = GitHubRepo(token)
        repo_info = repo.create(args.name, user, args.private)
        
        print(f"\nRepositório criado com sucesso!")
        print(f"URL: {repo_info['html_url']}")
        
        # Setup local e push
        print("\nConfigurando repositório local e fazendo push inicial...")
        repo.setup_local(repo_info['clone_url'], local_path)
        print(f"Push concluído com sucesso!")

    except Exception as e:
        print(f"Erro: {str(e)}")
        sys.exit(1)

def main(argv: Optional[Sequence[str]] = None) -> None:
    parser = argparse.ArgumentParser(
        description='''
GRepo - Gerenciador de Repositórios GitHub

Interface de linha de comando para gerenciar repositórios GitHub,
usando uma sintaxe familiar similar ao Git.

Principais comandos:
  create     Cria um novo repositório
  config     Gerencia configurações (similar ao git config)
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Comandos disponíveis')

    # Comando create
    create_parser = subparsers.add_parser('create',
        help='Cria um novo repositório',
        description='''
Cria um novo repositório no GitHub e configura o diretório local.

Exemplos:
  grepo create meu-repo            # Cria repositório público
  grepo create meu-repo --private  # Cria repositório privado
  grepo create repo --local ./dir  # Usa diretório específico
        '''
    )
    create_parser.add_argument('name',
        help='Nome do repositório a ser criado'
    )
    create_parser.add_argument('--private',
        action='store_true',
        help='Cria um repositório privado'
    )
    create_parser.add_argument('--local',
        default='.',
        help='Caminho do diretório local (default: atual)'
    )

    # Comando config
    config_parser = subparsers.add_parser('config',
        help='Gerencia configurações',
        description='''
Gerencia configurações do GRepo (similar ao git config).
As configurações são salvas em ~/.grepo

Exemplos:
  grepo config set user sindlinger     # Define usuário
  grepo config set token meu-token     # Define token
  grepo config get user                # Mostra usuário
  grepo config unset token             # Remove token
  grepo config unset --all             # Remove tudo
        '''
    )
    config_subparsers = config_parser.add_subparsers(dest='config_command')
    
    # Config set
    config_set = config_subparsers.add_parser('set',
        help='Define uma configuração'
    )
    config_set.add_argument('name',
        choices=['user', 'token'],
        help='Nome da configuração'
    )
    config_set.add_argument('value',
        help='Valor da configuração'
    )

    # Config get
    config_get = config_subparsers.add_parser('get',
        help='Obtém uma configuração'
    )
    config_get.add_argument('name',
        choices=['user', 'token'],
        help='Nome da configuração'
    )

    # Config unset
    config_unset = config_subparsers.add_parser('unset',
        help='Remove uma configuração'
    )
    config_unset.add_argument('name',
        choices=['user', 'token', '--all'],
        help='Nome da configuração (--all para remover tudo)'
    )

    args = parser.parse_args(argv)

    try:
        if args.command == 'create':
            create_cmd(args)
        elif args.command == 'config':
            if args.config_command == 'set':
                set_config(args.name, args.value)
            elif args.config_command == 'get':
                value = get_config(args.name)
                if value:
                    print(value)
            elif args.config_command == 'unset':
                unset_config(args.name)
            elif not args.config_command:
                show_config()
            else:
                config_parser.print_help()
        else:
            parser.print_help()
    except Exception as e:
        print(f"Erro: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    main()