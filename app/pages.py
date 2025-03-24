from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter()

@router.get("/", response_class=HTMLResponse)
def login_page():
    return """
    <h2>Login to Forecast API</h2>
    <form action="/token" method="post">
        <input name="username" placeholder="Email" /><br>
        <input name="password" type="password" placeholder="Password" /><br>
        <button type="submit">Login</button>
    </form>
    <p>Demo: alice@example.com / secret</p>
    """
