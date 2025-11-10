from __future__ import annotations

from datetime import datetime, timedelta

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from .config import settings
from .database import get_db
from .models import User
from .schemas import TokenData


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(user: User) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.jwt_expires_minutes)
    payload = {
        "sub": str(user.id),
        "exp": expire,
        "is_admin": user.is_admin,
        "allow_auto_credentials": user.allow_auto_credentials,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def get_user(db: Session, user_id: int) -> User | None:
    return db.query(User).filter(User.id == user_id).first()


def get_user_by_email(db: Session, email: str) -> User | None:
    return db.query(User).filter(User.email == email).first()


async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Não foi possível validar as credenciais",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        token_data = TokenData(
            user_id=int(user_id),
            is_admin=bool(payload.get("is_admin")),
            allow_auto_credentials=bool(payload.get("allow_auto_credentials")),
        )
    except JWTError as exc:
        raise credentials_exception from exc

    user = get_user(db, token_data.user_id)
    if user is None:
        raise credentials_exception
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Usuário inativo.")
    return user


async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Usuário inativo.")
    return current_user


async def get_current_admin(current_user: User = Depends(get_current_active_user)) -> User:
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Permissão insuficiente.")
    return current_user

