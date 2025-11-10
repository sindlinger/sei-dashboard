from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from .. import auth
from ..auth import create_access_token, get_current_admin, get_current_active_user, get_user_by_email, get_user
from ..database import get_db
from ..models import User
from ..schemas import Token, UserCreate, UserRead, UserUpdate

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = get_user_by_email(db, form_data.username)
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciais inválidas.")
    token = create_access_token(user)
    return Token(access_token=token)


@router.get("/me", response_model=UserRead)
def read_current_user(current_user: User = Depends(get_current_active_user)):
    return current_user


@router.post("/users", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    if get_user_by_email(db, payload.email):
        raise HTTPException(status_code=400, detail="E-mail já cadastrado.")

    user = User(
        email=payload.email,
        full_name=payload.full_name,
        hashed_password=auth.get_password_hash(payload.password),
        is_active=payload.is_active,
        is_admin=payload.is_admin,
        allow_auto_credentials=payload.allow_auto_credentials,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.patch("/users/{user_id}", response_model=UserRead)
def update_user(
    user_id: int,
    payload: UserUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    user = get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")

    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.password is not None:
        user.hashed_password = auth.get_password_hash(payload.password)
    if payload.is_active is not None:
        user.is_active = payload.is_active
    if payload.is_admin is not None:
        user.is_admin = payload.is_admin
    if payload.allow_auto_credentials is not None:
        user.allow_auto_credentials = payload.allow_auto_credentials

    db.commit()
    db.refresh(user)
    return user

