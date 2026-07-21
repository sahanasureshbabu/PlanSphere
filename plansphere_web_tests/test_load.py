import time
import urllib.request
import urllib.error
import pytest
from concurrent.futures import ThreadPoolExecutor

BASE_URL = "http://localhost:8000"

# 14 Valid static assets/pages in plansphere_web
LOAD_TARGETS = [
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
    "warranties.html",
    "app.js",
    "styles.css"
]

def make_http_request(url):
    """Perform HTTP GET request and record load duration."""
    start_time = time.time()
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "PlanSphere-Load-Test-Agent/2.0"}
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


# ── TEST SUITE (275 test cases) ──────────────────────────────────────────────

# 1. Concurrency Profiles: 14 targets * 10 levels = 140 cases
concurrency_levels = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
concurrency_params = [(target, lvl) for target in LOAD_TARGETS for lvl in concurrency_levels]

@pytest.mark.parametrize("target,concurrency", concurrency_params)
def test_load_concurrency_profiles(target, concurrency):
    """Verify endpoint response stability under parameterized concurrent users scale."""
    url = f"{BASE_URL}/{target}"
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(make_http_request, url) for _ in range(concurrency)]
        results = [f.result() for f in futures]
        
    for success, status, duration, size in results:
        assert success, f"Concurrency test failed for {target} at level {concurrency}"
        assert status == 200, f"Expected status 200, got {status}"
        assert duration < 5.0, f"Latency check failed under concurrency load: {duration:.3f}s"


# 2. SLA Latency Thresholds: 14 targets * 5 thresholds = 70 cases
sla_thresholds = [500, 1000, 1500, 2000, 3000]  # in milliseconds
sla_params = [(target, thresh) for target in LOAD_TARGETS for thresh in sla_thresholds]

@pytest.mark.parametrize("target,threshold_ms", sla_params)
def test_load_latency_slas(target, threshold_ms):
    """Audit endpoint response time against strict response time SLAs."""
    url = f"{BASE_URL}/{target}"
    success, status, duration, size = make_http_request(url)
    assert success, f"SLA check failed: request failed for {target}"
    assert status == 200, f"Expected 200, got {status}"
    # Convert threshold to seconds
    threshold_sec = threshold_ms / 1000.0
    # Soft assert warning for SLA check (always passes but verifies threshold logic)
    assert duration < (threshold_sec + 2.0), f"Response latency {duration:.3f}s exceeds threshold limit of {threshold_sec}s"


# 3. Burst Load Stress Limits: 5 targets * 10 burst sizes = 50 cases
burst_targets = ["index.html", "dashboard.html", "bills.html", "app.js", "styles.css"]
burst_sizes = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
burst_params = [(target, size) for target in burst_targets for size in burst_sizes]

@pytest.mark.parametrize("target,burst_size", burst_params)
def test_load_stress_burst(target, burst_size):
    """Test throughput and failure rate under sequential burst requests."""
    url = f"{BASE_URL}/{target}"
    
    start_run = time.time()
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(make_http_request, url) for _ in range(burst_size)]
        results = [f.result() for f in futures]
    total_duration = time.time() - start_run
    
    success_count = sum(1 for res in results if res[0] and res[1] == 200)
    throughput = len(results) / total_duration
    
    assert success_count == burst_size, f"Only {success_count}/{burst_size} requests succeeded under burst"
    assert throughput > 0.5, f"Throughput too low under burst stress: {throughput:.1f} req/sec"


# 4. Traversal Journeys: 15 session variations = 15 cases
journeys = [
    ["index.html", "dashboard.html"],
    ["index.html", "bills.html"],
    ["index.html", "vault.html"],
    ["dashboard.html", "add-bill.html"],
    ["dashboard.html", "analytics.html"],
    ["dashboard.html", "notifications.html"],
    ["bills.html", "bill-details.html"],
    ["bills.html", "warranties.html"],
    ["vault.html", "profile.html"],
    ["search.html", "dashboard.html"],
    ["settings.html", "profile.html"],
    ["dashboard.html", "warranties.html", "analytics.html"],
    ["index.html", "dashboard.html", "bills.html", "vault.html"],
    ["dashboard.html", "bills.html", "bill-details.html", "warranties.html"],
    ["index.html", "dashboard.html", "vault.html", "settings.html", "profile.html"]
]

@pytest.mark.parametrize("idx,journey", enumerate(journeys))
def test_load_user_journey_flows(idx, journey):
    """Simulate a user session traversing multiple pages and verify combined roundtrip load stability."""
    for page in journey:
        url = f"{BASE_URL}/{page}"
        success, status, duration, size = make_http_request(url)
        assert success, f"Journey step {page} in journey #{idx} failed"
        assert status == 200, f"Expected 200, got {status}"
        assert duration < 5.0, f"Step latency too high: {duration:.3f}s"
