import pytest

def get_auth_headers(client, phone="+919999900010"):
    # Log in and get headers
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

def test_create_listing(client):
    headers = get_auth_headers(client)
    
    # We will submit multipart form data
    data = {
        "name": "Quick Fix Plumbing",
        "category_id": 2, # Plumber is typically ID 2 based on seeding order
        "owner_name": "Ramesh Kumar",
        "owner_phone": "+919988776655",
        "latitude": 17.3850, # Hyderabad coordinates
        "longitude": 78.4867,
        "address": "Abids, Hyderabad",
        "working_days_json": "[1, 2, 3, 4, 5]",
        "working_hours": "9:00 AM - 6:00 PM",
        "description": "General household plumbing service"
    }
    
    response = client.post("/api/v1/listings/", data=data, headers=headers)
    assert response.status_code == 201
    res_data = response.json()
    assert res_data["name"] == "Quick Fix Plumbing"
    assert res_data["owner_phone"] == "+919988776655"
    assert res_data["status"] == "active"

def test_create_duplicate_listing_fails(client):
    headers1 = get_auth_headers(client, "+919999900011")
    headers2 = get_auth_headers(client, "+919999900012")
    
    data = {
        "name": "Super Spark Electrician",
        "category_id": 1, # Electrician
        "owner_name": "Suresh",
        "owner_phone": "+918888877777",
        "latitude": 17.4000,
        "longitude": 78.5000,
        "address": "Secunderabad",
        "working_days_json": "[1, 2, 3, 4, 5, 6]",
        "working_hours": "10:00 AM - 8:00 PM",
        "description": "Electrician"
    }
    
    # First creation should succeed
    resp1 = client.post("/api/v1/listings/", data=data, headers=headers1)
    assert resp1.status_code == 201
    
    # Second creation with same category and owner phone should fail with 409
    resp2 = client.post("/api/v1/listings/", data=data, headers=headers2)
    assert resp2.status_code == 409
    assert resp2.json()["detail"]["error"] == "duplicate_exists"
    assert "existing_listing_id" in resp2.json()["detail"]

def test_nearby_search_distance_sorting(client):
    headers = get_auth_headers(client)
    
    # Create listing 1 (Near: Charminar - ~17.3616, 78.4747)
    client.post("/api/v1/listings/", data={
        "name": "Charminar Plumber",
        "category_id": 2,
        "owner_name": "Ali",
        "owner_phone": "+917777700001",
        "latitude": 17.3616,
        "longitude": 78.4747,
        "address": "Charminar Area",
        "working_days_json": "[1,2,3,4,5]",
        "working_hours": "8:00 AM - 5:00 PM"
    }, headers=headers)

    # Create listing 2 (Far: Gachibowli - ~17.4400, 78.3480)
    client.post("/api/v1/listings/", data={
        "name": "Gachibowli Plumber",
        "category_id": 2,
        "owner_name": "Venkatesh",
        "owner_phone": "+917777700002",
        "latitude": 17.4400,
        "longitude": 78.3480,
        "address": "Gachibowli Area",
        "working_days_json": "[1,2,3,4,5]",
        "working_hours": "9:00 AM - 6:00 PM"
    }, headers=headers)

    # Search from Charminar coordinates (17.3616, 78.4747) with sorting by distance
    search_resp = client.get(
        "/api/v1/listings/",
        params={
            "category_id": 2,
            "latitude": 17.3616,
            "longitude": 78.4747,
            "sort_by": "distance"
        }
    )
    assert search_resp.status_code == 200
    results = search_resp.json()
    assert len(results) >= 2
    # First result should be Charminar Plumber (closest)
    assert results[0]["name"] == "Charminar Plumber"
    assert results[0]["distance"] == 0.0
    assert results[1]["name"] == "Gachibowli Plumber"
    assert results[1]["distance"] > 10.0 # Gachibowli is ~15km from Charminar
