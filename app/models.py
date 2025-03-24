from pydantic import BaseModel
from typing import Dict

class User(BaseModel):
    username: str
    hashed_password: str

# Demo user: alice@example.com / secret
fake_users_db: Dict[str, User] = {
    "alice@example.com": User(
        username="alice@example.com",
        hashed_password="$2b$12$KIX2JYmKHsrbn5K9wzPqVuVWVQ91qXb/tTwXEvKnVfUGaekpFLNIS"
    )
}
