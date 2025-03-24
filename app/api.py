from pydantic import BaseModel

class ForecastRequest(BaseModel):
    forecast_date: str
    current_price: float
    asset_class: str

def forecast_price(request: ForecastRequest):
    # Placeholder logic (e.g., +5%)
    forecasted_price = round(request.current_price * 1.05, 2)
    return {
        "forecast_date": request.forecast_date,
        "current_price": request.current_price,
        "asset_class": request.asset_class,
        "forecasted_price": forecasted_price
    }

