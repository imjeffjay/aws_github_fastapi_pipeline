import streamlit as st
import requests
import os

# ========================
# API URL Configuration
# ========================
API_URL = os.getenv("API_URL") or st.secrets.get("API_URL", "http://localhost:8000")

# ========================
# Initialize Session State
# ========================
if "token" not in st.session_state:
    st.session_state["token"] = None
if "view" not in st.session_state:
    st.session_state["view"] = "login"

# ========================
# Navigation Logic
# ========================
def go_to(view_name: str):
    st.session_state["view"] = view_name
    st.experimental_rerun()

# ========================
# Login View
# ========================
def login_view():
    st.title("Credit Risk Predictor")
    st.subheader("Login")

    username = st.text_input("Email")
    password = st.text_input("Password", type="password")

    if st.button("Login"):
        token_resp = requests.post(f"{API_URL}/token", data={
            "username": username,
            "password": password
        })

        if token_resp.status_code == 200:
            st.session_state["token"] = token_resp.json()["access_token"]
            go_to("dashboard")
        else:
            st.error("Invalid credentials.")

# ========================
# Dashboard View
# ========================
def dashboard_view():
    st.title("Credit Risk Predictor")
    st.success("You are logged in.")

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
                f"{API_URL}/api/forecast",
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
                result = response.json()
                st.subheader("Forecast Result")

                col1, col2 = st.columns(2)
                with col1:
                    st.metric("Risk Score", result.get("risk_score", "N/A"))
                    st.write("Model Version:", result.get("model_version", "N/A"))
                with col2:
                    st.write("Risk Level:", f"**{result.get('risk_level', 'N/A')}**")
                    st.write("Recommendation:", f"**{result.get('recommendation', 'N/A')}**")
                    st.caption(result.get("explanation", "No explanation provided."))
            else:
                st.error(f"Request failed: {response.status_code}")
                st.code(response.text)

    if st.button("Logout"):
        st.session_state["token"] = None
        go_to("login")

# ========================
# View Dispatcher
# ========================
if st.session_state["view"] == "login":
    login_view()
elif st.session_state["view"] == "dashboard":
    if not st.session_state["token"]:
        go_to("login")
    else:
        dashboard_view()


