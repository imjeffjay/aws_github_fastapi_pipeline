from fastapi import FastAPI, Depends, Request, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from app.api import forecast_price, ForecastRequest
from app.auth import router as auth_router, get_current_user
from app.models import User

app = FastAPI(
    title="Secure Forecast API",
    description="Demo with login + token + model",
    version="0.1"
)

# Include auth routes
app.include_router(auth_router)

# HTML template setup
templates = Jinja2Templates(directory="fastapi_frontend/templates")

# Public homepage using Jinja2
@app.get("/", response_class=HTMLResponse)
def root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request, "message": "Enter data to forecast."})

# Forecast form handler (NOT secured)
@app.post("/predict", response_class=HTMLResponse)
def predict(
    request: Request,
    input_data: str = Form(...),
):
    # This is a placeholder until we wire it to your model
    result = f"Received input: {input_data}"
    return templates.TemplateResponse("index.html", {
        "request": request,
        "message": "Submitted to /predict",
        "result": result
    })

# Secured API forecast route (same as before)
@app.post("/forecast")
def secured_forecast(request: ForecastRequest, user: User = Depends(get_current_user)):
    return forecast_price(request)
