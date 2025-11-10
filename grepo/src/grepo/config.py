"""
Gerenciamento de configurações do GRepo.
Armazena e gerencia configurações de forma similar ao Git.
"""

import os
import json
from pathlib import Path
from typing import Optional, Dict, Any

CONFIG_FILE = Path.home() / '.grepo'

def load_config() -> Dict[str, Any]:
    """Carrega as configurações do arquivo."""
    if CONFIG_FILE.exists():
        try:
            return json.loads(CONFIG_FILE.read_text())
        except json.JSONDecodeError:
            return {}
    return {}

def save_config(config: Dict[str, Any]) -> None:
    """Salva as configurações no arquivo."""
    CONFIG_FILE.write_text(json.dumps(config, indent=2))
    os.chmod(CONFIG_FILE, 0o600)  # Apenas o usuário pode ler/escrever

def set_config(name: str, value: str) -> None:
    """
    Define uma configuração.
    Similar ao 'git config --set'
    """
    config = load_config()
    config[name] = value
    save_config(config)
    print(f"Configuração '{name}' definida com sucesso!")

def unset_config(name: str) -> None:
    """
    Remove uma configuração.
    Similar ao 'git config --unset'
    """
    if name == '--all':
        if CONFIG_FILE.exists():
            CONFIG_FILE.unlink()
            print("Todas as configurações foram removidas!")
        return

    config = load_config()
    if name in config:
        del config[name]
        save_config(config)
        print(f"Configuração '{name}' removida!")
    else:
        print(f"Configuração '{name}' não encontrada!")

def get_config(name: str) -> Optional[str]:
    """
    Obtém uma configuração específica.
    
    Args:
        name: Nome da configuração
    """
    config = load_config()
    return config.get(name)

def show_config() -> None:
    """
    Mostra todas as configurações.
    """
    config = load_config()
    if not config:
        print("Nenhuma configuração encontrada!")
        return

    print("\nConfigurações:")
    print("-" * 30)
    for key, value in config.items():
        print(f"{key} = {value}")

def get_required_config(name: str) -> str:
    """
    Obtém uma configuração, levantando erro se não existir.
    """
    value = get_config(name)
    if not value:
        raise ValueError(
            f"Configuração '{name}' não encontrada!\n"
            f"Use 'grepo config set {name} <valor>' para configurar."
        )
    return value