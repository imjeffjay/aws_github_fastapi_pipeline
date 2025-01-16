from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional

app = FastAPI()

class ForecastRequest(BaseModel):
    forecast_date: str
    current_price: float
    asset_class: str

@app.post("/forecast")
def forecast_price(request: ForecastRequest):
    return {
        "forecast_date": request.forecast_date,
        "current_price": request.current_price,
        "asset_class": request.asset_class,
        "forecasted_price": 999.0
    }
