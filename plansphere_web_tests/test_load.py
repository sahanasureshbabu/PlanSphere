import time
import urllib.request
import urllib.error
import pytest
from concurrent.futures import ThreadPoolExecutor

BASE_URL = "http://localhost:8000"

WEB_PAGES = [
    "index.html",
    "dashboard.html",
    "add-bill.html",
    "bills.html",
    "bill-details.html",
    "vault.html",
    "analytics.html",
    "notifications.html",
    "profile.html",
    "search.html",
    "settings.html",
    "warranties.html"
]

def make_http_request(url):
    """Utility helper to perform HTTP GET requests and record diagnostics."""
    start_time = time.time()
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "PlanSphere-Load-Test-Agent/1.0"}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            status = response.status
            content = response.read()
            duration = time.time() - start_time
            return True, status, duration, len(content)
    except urllib.error.HTTPError as e:
        return False, e.code, time.time() - start_time, 0
    except Exception:
        return False, 500, time.time() - start_time, 0

# 1. Parameterized Low Concurrency Tests (5 Virtual Users)
@pytest.mark.parametrize("page", WEB_PAGES)
def test_load_low_concurrency(page):
    """Measure response latency and request success under low concurrent user loads (5 users)."""
    url = f"{BASE_URL}/{page}"
    concurrency = 5
    
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(make_http_request, url) for _ in range(concurrency)]
        results = [f.result() for f in futures]
        
    for success, status, duration, size in results:
        assert success, f"Request failed for {page} with status {status}"
        assert status == 200, f"Expected status 200, got {status}"
        # Localhost simple static servers are extremely fast, latency should be low
        assert duration < 0.25, f"Response time too high: {duration:.3f}s"

# 2. Parameterized Medium Concurrency Tests (15 Virtual Users)
@pytest.mark.parametrize("page", WEB_PAGES)
def test_load_medium_concurrency(page):
    """Measure response latency and request success under medium concurrent user loads (15 users)."""
    url = f"{BASE_URL}/{page}"
    concurrency = 15
    
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(make_http_request, url) for _ in range(concurrency)]
        results = [f.result() for f in futures]
        
    for success, status, duration, size in results:
        assert success, f"Request failed for {page} with status {status}"
        assert status == 200, f"Expected status 200, got {status}"
        assert duration < 0.35, f"Response time too high: {duration:.3f}s"

# 3. Parameterized High Concurrency Tests (30 Virtual Users)
@pytest.mark.parametrize("page", WEB_PAGES)
def test_load_high_concurrency(page):
    """Measure response latency and request success under high concurrent user loads (30 users)."""
    url = f"{BASE_URL}/{page}"
    concurrency = 30
    
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(make_http_request, url) for _ in range(concurrency)]
        results = [f.result() for f in futures]
        
    for success, status, duration, size in results:
        assert success, f"Request failed for {page} with status {status}"
        assert status == 200, f"Expected status 200, got {status}"
        assert duration < 0.50, f"Response time too high: {duration:.3f}s"

# 4. Stress and Peak Load limits
def test_load_stress_burst():
    """Burst testing of 100 requests sequentially mapped across 10 threads to verify backend throughput resilience."""
    url = f"{BASE_URL}/index.html"
    total_requests = 100
    concurrency = 10
    
    start_run = time.time()
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(make_http_request, url) for _ in range(total_requests)]
        results = [f.result() for f in futures]
    total_duration = time.time() - start_run
    
    success_count = sum(1 for res in results if res[0] and res[1] == 200)
    throughput = len(results) / total_duration
    
    assert success_count == total_requests, f"Only {success_count}/{total_requests} requests succeeded under burst"
    assert throughput > 50, f"Throughput under stress too low: {throughput:.1f} req/sec"

# 5. Sequential Session Load Simulation
def test_load_sequential_session():
    """Simulate a user session journey traversing multiple views to check combined roundtrip page response times."""
    journey = ["index.html", "dashboard.html", "bills.html", "vault.html", "settings.html"]
    
    for page in journey:
        url = f"{BASE_URL}/{page}"
        success, status, duration, size = make_http_request(url)
        assert success, f"Journey step {page} failed"
        assert status == 200, f"Journey step {page} returned status {status}"
        assert duration < 0.15, f"Journey step {page} took too long: {duration:.3f}s"
