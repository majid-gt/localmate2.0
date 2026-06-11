import pytest

def get_auth_headers(client, phone):
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

def test_reviews_and_reputation_progression(client):
    # Setup Contributor A
    contrib_headers = get_auth_headers(client, "+919999900020")
    
    # Get user profile A id
    profile_resp = client.get("/api/v1/users/me", headers=contrib_headers)
    contrib_id = profile_resp.json()["id"]
    assert profile_resp.json()["reputation"]["points"] == 0
    assert profile_resp.json()["reputation"]["reputation_level"] == "Bronze Contributor"

    # Contributor A creates a listing
    data = {
        "name": "Reliable Tailor Shop",
        "category_id": 5, # Tailor
        "owner_name": "Rizwan",
        "owner_phone": "+919999988888",
        "latitude": 17.3850,
        "longitude": 78.4867,
        "address": "Koti, Hyderabad",
        "working_days_json": "[1,2,3,4,5,6]",
        "working_hours": "9:00 AM - 9:00 PM"
    }
    create_resp = client.post("/api/v1/listings/", data=data, headers=contrib_headers)
    assert create_resp.status_code == 201
    listing_id = create_resp.json()["id"]

    # Contributor A reputation should now have +10 points (for 1 active listing)
    profile_resp2 = client.get("/api/v1/users/me", headers=contrib_headers)
    assert profile_resp2.json()["reputation"]["total_listings"] == 1
    assert profile_resp2.json()["reputation"]["points"] == 10

    # User B (Newcomer) reviews listing with 5 stars
    newcomer_headers = get_auth_headers(client, "+919999900021")
    review_resp = client.post(
        f"/api/v1/reviews/listings/{listing_id}",
        json={"rating": 5, "comment": "Excellent work!"},
        headers=newcomer_headers
    )
    assert review_resp.status_code == 201

    # Contributor A reputation should increase by 10 points (5 stars * 2) = total 20 points
    profile_resp3 = client.get(f"/api/v1/users/{contrib_id}")
    assert profile_resp3.json()["reputation"]["points"] == 20
    assert profile_resp3.json()["reputation"]["total_reviews"] == 1
    assert profile_resp3.json()["reputation"]["avg_rating"] == 5.0

    # User B reviews Contributor A directly with 5 stars
    contrib_review_resp = client.post(
        f"/api/v1/reviews/users/{contrib_id}",
        json={"rating": 5, "comment": "Always posts great recommendations!"},
        headers=newcomer_headers
    )
    assert contrib_review_resp.status_code == 201

    # Contributor A reputation points: 20 base + (5 stars * 5) = 45 points
    profile_resp4 = client.get(f"/api/v1/users/{contrib_id}")
    assert profile_resp4.json()["reputation"]["points"] == 45
    assert profile_resp4.json()["reputation"]["total_reviews"] == 2
    assert profile_resp4.json()["reputation"]["avg_rating"] == 5.0

    # Create lots of listings to level up to Gold Contributor (> 500 points)
    # We will simulate listing additions directly in the loop (creating 50 listings)
    # 50 listings * 10 points = 500 points
    for i in range(50):
        client.post("/api/v1/listings/", data={
            "name": f"Mock Business {i}",
            "category_id": 1,
            "owner_name": f"Owner {i}",
            "owner_phone": f"+919900000{i:03d}",
            "latitude": 17.3850,
            "longitude": 78.4867,
            "address": "Hyderabad",
            "working_days_json": "[1]",
            "working_hours": "9-6"
        }, headers=contrib_headers)

    profile_resp5 = client.get(f"/api/v1/users/{contrib_id}")
    assert profile_resp5.json()["reputation"]["points"] >= 500
    assert profile_resp5.json()["reputation"]["reputation_level"] == "Gold Contributor"
