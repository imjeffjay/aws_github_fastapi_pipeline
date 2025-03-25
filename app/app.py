import streamlit as st
import requests

st.title("Credit Risk Predictor")

# Initialize session state for the token
if "token" not in st.session_state:
    st.session_state["token"] = None

# Login form
username = st.text_input("Email")
password = st.text_input("Password", type="password")

if st.button("Login"):
    token_resp = requests.post("http://localhost:8000/token", data={
        "username": username,
        "password": password
    })

    if token_resp.status_code == 200:
        st.session_state["token"] = token_resp.json()["access_token"]
        st.success("Logged in!")
    else:
        st.error("Invalid credentials.")

# Show forecast form only if logged in
if st.session_state["token"]:
    with st.form("forecast_form"):
        age = st.number_input("Age", 18, 100, 35)
        income = st.number_input("Income", 0, 500000, 72000)
        loan_amount = st.number_input("Loan Amount", 0, 100000, 15000)
        credit_score = st.number_input("Credit Score", 300, 850, 670)
        existing_debt = st.number_input("Existing Debt", 0, 100000, 3200)
        employment_years = st.number_input("Employment Years", 0, 40, 5)
        submitted = st.form_submit_button("Submit")

        if submitted:
            response = requests.post(
                "http://localhost:8000/forecast",
                headers={"Authorization": f"Bearer {st.session_state['token']}"},
                json={
                    "age": age,
                    "income": income,
                    "loan_amount": loan_amount,
                    "credit_score": credit_score,
                    "existing_debt": existing_debt,
                    "employment_years": employment_years
                }
            )
            if response.status_code == 200:
                st.subheader("Forecast Result")
                st.json(response.json())
            else:
                st.error(f"Request failed: {response.status_code}")
