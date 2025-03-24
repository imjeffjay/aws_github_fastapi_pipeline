from fastapi import FastAPI, Depends
from app.api import forecast_price, ForecastRequest
from app.auth import router as auth_router, get_current_user
from app.pages import router as pages_router
from app.models import User

app = FastAPI(
    title="Secure Forecast API",
    description="Demo with login + token + model",
    version="0.1"
)

# Include auth and HTML routes
app.include_router(auth_router)
app.include_router(pages_router)

# Protected forecast endpoint
@app.post("/forecast")
def secured_forecast(request: ForecastRequest, user: User = Depends(get_current_user)):
    return forecast_price(request)