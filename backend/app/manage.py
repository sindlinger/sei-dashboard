from __future__ import annotations

import argparse
from getpass import getpass

from . import auth
from .database import Base, engine, SessionLocal
from .models import User


def create_admin(email: str, password: str, full_name: str | None = None) -> None:
    session = SessionLocal()
    try:
        existing = session.query(User).filter(User.email == email).first()
        if existing:
            raise ValueError("Já existe um usuário com esse e-mail.")
        user = User(
            email=email,
            full_name=full_name,
            hashed_password=auth.get_password_hash(password),
            is_active=True,
            is_admin=True,
            allow_auto_credentials=True,
        )
        session.add(user)
        session.commit()
        print(f"Usuário admin criado: {email}")
    finally:
        session.close()


def main():
    parser = argparse.ArgumentParser(description="Gerenciar usuários do SEIAutomation API.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    create_parser = subparsers.add_parser("create-admin", help="Criar usuário administrador")
    create_parser.add_argument("--email", required=True, help="E-mail do novo admin")
    create_parser.add_argument("--full-name", help="Nome completo (opcional)")
    create_parser.add_argument("--password", help="Senha (se omitida, será solicitada)")

    args = parser.parse_args()
    Base.metadata.create_all(bind=engine)

    if args.command == "create-admin":
        password = args.password or getpass("Senha: ")
        create_admin(args.email, password, args.full_name)


if __name__ == "__main__":
    main()

