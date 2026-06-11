import pytest

def test_send_otp(client):
    response = client.post(
        "/api/v1/auth/otp/send",
        json={"phone_number": "+919999900000"}
    )
    assert response.status_code == 200
    assert response.json()["message"] == "OTP sent successfully"
    assert "debug_code" in response.json()

def test_verify_otp_new_user(client):
    # Send OTP to get code
    phone = "+919999900000"
    send_resp = client.post(
        "/api/v1/auth/otp/send",
        json={"phone_number": phone}
    )
    code = send_resp.json()["debug_code"]
    
    # Verify OTP
    verify_resp = client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": phone, "code": code}
    )
    assert verify_resp.status_code == 200
    data = verify_resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["is_new_user"] is True

def test_verify_otp_existing_user(client):
    phone = "+919999900001"
    # First login (create user)
    send_resp = client.post(
        "/api/v1/auth/otp/send",
        json={"phone_number": phone}
    )
    code = send_resp.json()["debug_code"]
    
    client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": phone, "code": code}
    )
    
    # Second login
    send_resp = client.post(
        "/api/v1/auth/otp/send",
        json={"phone_number": phone}
    )
    code = send_resp.json()["debug_code"]
    
    verify_resp = client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": phone, "code": code}
    )
    assert verify_resp.status_code == 200
    assert verify_resp.json()["is_new_user"] is False

def test_google_login(client):
    response = client.post(
        "/api/v1/auth/google",
        json={"id_token": "mock-google-token", "name": "Google Tester", "email": "tester@gmail.com"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["is_new_user"] is True
