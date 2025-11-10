from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, EmailStr, Field


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: int
    is_admin: bool
    allow_auto_credentials: bool


class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    is_active: bool = True
    is_admin: bool = False
    allow_auto_credentials: bool = False


class UserCreate(UserBase):
    password: str = Field(..., min_length=8)


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    password: Optional[str] = Field(default=None, min_length=8)
    is_active: Optional[bool] = None
    is_admin: Optional[bool] = None
    allow_auto_credentials: Optional[bool] = None


class UserRead(UserBase):
    id: int

    class Config:
        from_attributes = True


class TaskDefinition(BaseModel):
    name: str
    slug: str
    description: str


class TaskRunCreate(BaseModel):
    task_slug: str
    headless: bool = True
    auto_credentials: bool = True
    limit: Optional[int] = None


class TaskRunRead(BaseModel):
    id: str
    task_name: str
    status: str
    log: str
    created_at: datetime
    finished_at: Optional[datetime]
    params: Optional[Any]

    class Config:
        from_attributes = True

