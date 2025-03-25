from pydantic import BaseModel

class ForecastRequest(BaseModel):
    age: int
    income: float
    loan_amount: float
    credit_score: int
    existing_debt: float
    employment_years: int

def forecast_price(request: ForecastRequest):
    # Dummy logic for now
    risk_score = round(request.loan_amount / max(request.income, 1), 2)
    return {
        "risk_score": risk_score,
        "risk_level": "low",
        "recommendation": "approve",
        "explanation": "Demo result",
        "model_version": "v1.0"
    }


