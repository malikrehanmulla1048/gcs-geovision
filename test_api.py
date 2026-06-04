import requests
import sys
import time

BASE_URL = "http://localhost:8000"

def test_health():
    res = requests.get(f"{BASE_URL}/health")
    assert res.status_code == 200, "Health endpoint failed"
    data = res.json()
    assert "cpu_percent" in data
    print("Health check passed")

def test_auth_and_user():
    # Try logging in with the seeded admin account
    res = requests.post(f"{BASE_URL}/auth/login", json={
        "email": "admin@reva.edu.in",
        "password": "Admin@GeoVision2025"
    })
    assert res.status_code == 200, "Admin login failed"
    data = res.json()
    assert data["ok"] is True
    assert data["user"]["role"] == "admin"
    print("Auth login passed")
    
    # Try fetching users
    res = requests.get(f"{BASE_URL}/users")
    assert res.status_code == 200, "Users endpoint failed"
    print("Get all users passed")

def test_stats():
    res = requests.get(f"{BASE_URL}/stats")
    assert res.status_code == 200, "Stats endpoint failed"
    data = res.json()
    assert "active_threats" in data
    print("Stats endpoint passed")

def test_entry_logs():
    res = requests.get(f"{BASE_URL}/entry_logs")
    assert res.status_code == 200, "Entry logs endpoint failed"
    assert isinstance(res.json(), list)
    print("Entry logs endpoint passed")

def test_visitors():
    # Get visitors
    res = requests.get(f"{BASE_URL}/visitors")
    assert res.status_code == 200, "Visitors get failed"
    print("Get visitors passed")
    
    # Add visitor
    res = requests.post(f"{BASE_URL}/visitors", json={
        "name": "Test Visitor",
        "phone": "1234567890",
        "purpose": "Testing",
        "host": "Admin",
        "dept": "IT",
        "id_number": "V123",
        "gate": "Main Gate"
    })
    assert res.status_code == 200, "Add visitor failed"
    vid = res.json()["visitor_id"]
    print("Add visitor passed")
    
    # Checkout visitor
    res = requests.post(f"{BASE_URL}/visitors/{vid}/checkout")
    assert res.status_code == 200, "Checkout visitor failed"
    print("Checkout visitor passed")

if __name__ == "__main__":
    # Wait for backend to be ready
    for _ in range(15):
        try:
            if requests.get(f"{BASE_URL}/health").status_code == 200:
                break
        except requests.exceptions.ConnectionError:
            time.sleep(1)
    else:
        print("Backend did not start in time.")
        sys.exit(1)

    print("Running API tests...")
    try:
        test_health()
        test_auth_and_user()
        test_stats()
        test_entry_logs()
        test_visitors()
        print("\nALL TESTS PASSED!")
    except AssertionError as e:
        print(f"\nTEST FAILED: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\nUNEXPECTED ERROR: {e}")
        sys.exit(1)
