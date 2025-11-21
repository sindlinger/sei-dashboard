"""
Core functionality para interação com o GitHub.
"""

import os
import requests
from typing import Dict, Any

class GitHubRepo:
    def __init__(self, token: str):
        self.token = token
        self.headers = {
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json'
        }

    def create(self, name: str, owner: str, private: bool = False) -> Dict[str, Any]:
        """
        Cria um novo repositório no GitHub.
        Similar ao 'git init' + configuração remota.
        """
        data = {
            'name': name,
            'private': private,
            'auto_init': False
        }

        response = requests.post(
            'https://api.github.com/user/repos',
            headers=self.headers,
            json=data
        )

        if response.status_code != 201:
            raise Exception(
                f"Erro ao criar repositório: {response.json().get('message', 'Erro desconhecido')}"
            )

        return response.json()

    @staticmethod
    def setup_local(repo_url: str, local_path: str = '.') -> None:
        """
        Configura o repositório local e faz push inicial.
        Similar ao 'git remote add' + 'git push'.
        """
        commands = [
            ('git init', "Erro ao inicializar repositório git"),
            (f'git remote add origin {repo_url}', "Erro ao adicionar remote"),
            ('git add .', "Erro ao adicionar arquivos"),
            ('git commit -m "Initial commit"', "Erro ao criar commit inicial"),
            ('git push -u origin master', "Erro ao fazer push para o GitHub")
        ]

        os.chdir(local_path)
        for cmd, error_msg in commands:
            if os.system(cmd) != 0:
                raise Exception(error_msg)