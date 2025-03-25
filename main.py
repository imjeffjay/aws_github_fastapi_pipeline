from fastapi import FastAPI, Depends, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
import requests

from app.api import forecast_price, ForecastRequest
from app.auth import router as auth_router
from app.models import User

app = FastAPI(title="Secure Forecast API", description="Demo with login + token + model", version="0.1")
app.include_router(auth_router)

templates = Jinja2Templates(directory="fastapi_frontend/templates")

@app.get("/", response_class=HTMLResponse)
def login_page(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.post("/login", response_class=HTMLResponse)
def handle_login(request: Request, username: str = Form(...), password: str = Form(...)):
    response = requests.post("http://localhost:8000/token", data={"username": username, "password": password})
    
    if response.status_code == 200:
        token = response.json()["access_token"]
        return templates.TemplateResponse("dashboard.html", {
            "request": request,
            "token": token,
            "result": None
        })
    else:
        return templates.TemplateResponse("login.html", {
            "request": request,
            "error": "Invalid credentials"
        })

@app.post("/forecast", response_class=HTMLResponse)
def handle_forecast(
    request: Request,
    token: str = Form(...),
    age: int = Form(...),
    income: int = Form(...),
    loan_amount: int = Form(...),
    credit_score: int = Form(...),
    existing_debt: int = Form(...),
    employment_years: int = Form(...)
):
    response = requests.post("http://localhost:8000/forecast",
                             headers={"Authorization": f"Bearer {token}"},
                             json={
                                 "age": age,
                                 "income": income,
                                 "loan_amount": loan_amount,
                                 "credit_score": credit_score,
                                 "existing_debt": existing_debt,
                                 "employment_years": employment_years
                             })
    
    if response.status_code == 200:
        result = response.json()
    else:
        result = f"Error {response.status_code}: {response.text}"

    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "token": token,
        "result": result
    })

