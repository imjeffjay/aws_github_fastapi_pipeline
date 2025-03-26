from pydantic import BaseModel
from typing import Dict
from passlib.context import CryptContext

class User(BaseModel):
    username: str
    hashed_password: str

# Local password hasher (copied from auth.py)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

# Fake user database
fake_users_db: Dict[str, User] = {
    "claire@claire.com": User(
        username="claire@claire.com",
        hashed_password=get_password_hash("claire")
    ),
    "jeff@jeff.com": User(
        username="jeff@jeff.com",
        hashed_password=get_password_hash("jeff")
    )
}