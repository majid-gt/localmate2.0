import pytest
from app.api.v1.admin import ADMIN_SECRET

def get_auth_headers(client, phone="+919999900020"):
    send_resp = client.post(
        "/api/v1/auth/otp/send",
        json={"phone_number": phone}
    )
    code = send_resp.json()["debug_code"]
    verify_resp = client.post(
        "/api/v1/auth/otp/verify",
        json={"phone_number": phone, "code": code}
    )
    token = verify_resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

def test_admin_suggestions_flow(client):
    user_headers = get_auth_headers(client)
    
    # 1. Create a listing to suggest edits on
    listing_data = {
        "name": "Suggestion Test Service",
        "category_id": 1,
        "owner_name": "Test Owner",
        "owner_phone": "+919999999999",
        "latitude": 17.3850,
        "longitude": 78.4867,
        "address": "Test Address",
        "working_days_json": "[1, 2, 3, 4, 5]",
        "working_hours": "9:00 AM - 6:00 PM"
    }
    create_resp = client.post("/api/v1/listings/", data=listing_data, headers=user_headers)
    assert create_resp.status_code == 201
    listing_id = create_resp.json()["id"]
    
    # 2. Submit suggestion
    suggest_data = {"comment": "Phone number is changed to +919999999998"}
    suggest_resp = client.post(f"/api/v1/listings/{listing_id}/suggestions", json=suggest_data, headers=user_headers)
    assert suggest_resp.status_code == 200
    suggestion_id = suggest_resp.json()["id"]
    assert suggest_resp.json()["status"] == "pending"
    
    # 3. Try to get all suggestions as unauthorized admin
    get_suggestions_unauth = client.get("/api/v1/admin/suggestions", headers={"x-admin-secret": "wrong_key"})
    assert get_suggestions_unauth.status_code == 401
    
    # 4. Get all suggestions as authorized admin
    get_suggestions_auth = client.get("/api/v1/admin/suggestions", headers={"x-admin-secret": ADMIN_SECRET})
    assert get_suggestions_auth.status_code == 200
    suggestions = get_suggestions_auth.json()
    assert len(suggestions) >= 1
    
    # Find our suggestion
    our_suggestion = next((s for s in suggestions if s["id"] == suggestion_id), None)
    assert our_suggestion is not None
    assert our_suggestion["comment"] == "Phone number is changed to +919999999998"
    assert our_suggestion["listing_name"] == "Suggestion Test Service"
    assert our_suggestion["status"] == "pending"
    
    # 5. Resolve suggestion
    resolve_resp = client.put(f"/api/v1/admin/suggestions/{suggestion_id}/resolve", headers={"x-admin-secret": ADMIN_SECRET})
    assert resolve_resp.status_code == 200
    assert resolve_resp.json()["status"] == "resolved"
    
    # 6. Check that get suggestions now returns resolved status
    get_suggestions_again = client.get("/api/v1/admin/suggestions", headers={"x-admin-secret": ADMIN_SECRET})
    updated_suggestions = get_suggestions_again.json()
    our_updated = next((s for s in updated_suggestions if s["id"] == suggestion_id), None)
    assert our_updated["status"] == "resolved"
