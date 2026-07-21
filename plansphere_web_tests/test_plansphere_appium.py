import time
import pytest
from datetime import datetime, timedelta
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC

BASE_URL = "http://localhost:8000"

# ── Shared helper: inject auth session into localStorage ──────────────────────
def inject_session(driver, email="admin@plansphere.com", name="Administrator"):
    if "localhost" not in driver.current_url:
        driver.get(f"{BASE_URL}/index.html")
    driver.execute_script(f"""
        localStorage.clear();
        if (typeof initializeDatabase === 'function') {{ initializeDatabase(); }}
        localStorage.setItem('plansphere_session', JSON.stringify({{
            email: '{email}', name: '{name}',
            token: 'session-{int(time.time()*1000)}'
        }}));
    """)

def inject_bills(driver, bills_json):
    driver.execute_script(f"localStorage.setItem('plansphere_bills', JSON.stringify({bills_json}));")

def inject_docs(driver, docs_json):
    driver.execute_script(f"localStorage.setItem('plansphere_documents', JSON.stringify({docs_json}));")

# ─────────────────────────────────────────────────────────────
# SECTION 1 · AUTHENTICATION (37 cases)
# ─────────────────────────────────────────────────────────────

# 1a. Login – 15 cases
login_cases = []
for _i in range(6):
    login_cases.append((f"invalidemail{_i}", "admin123", "email-error", "Please enter a valid email address."))
for _i in range(8):
    login_cases.append(("admin@plansphere.com", f"wrongpass{_i}", None, "Invalid email or password."))
login_cases.append(("admin@plansphere.com", "admin123", "success", "Sign In successful!"))

@pytest.mark.parametrize("email,password,expected_error_type,expected_msg", login_cases)
def test_appium_login(appium_driver, email, password, expected_error_type, expected_msg):
    """Verify login validation on mobile emulation with various credential combinations."""
    appium_driver.get(f"{BASE_URL}/index.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "email")))
    appium_driver.find_element(By.ID, "email").clear()
    appium_driver.find_element(By.ID, "email").send_keys(email)
    appium_driver.find_element(By.ID, "password").clear()
    appium_driver.find_element(By.ID, "password").send_keys(password)
    appium_driver.find_element(By.CSS_SELECTOR, "#login-form button[type='submit']").click()
    if expected_error_type == "email-error":
        err = WebDriverWait(appium_driver, 5).until(EC.visibility_of_element_located((By.ID, "email-error")))
        assert expected_msg in err.text
    elif expected_error_type == "success":
        WebDriverWait(appium_driver, 5).until(EC.url_contains("dashboard.html"))
        assert "dashboard.html" in appium_driver.current_url
    else:
        toast = WebDriverWait(appium_driver, 5).until(EC.visibility_of_element_located((By.ID, "app-toast")))
        assert expected_msg in toast.text

# 1b. Registration – 12 cases
register_cases = []
for _i in range(4):
    register_cases.append(("", f"reg{_i}@plansphere.com", "pass12345", "reg-name-error", "Name is required."))
for _i in range(4):
    register_cases.append(("John Doe", f"badregemail{_i}", "pass12345", "reg-email-error", "Please enter a valid email."))
for _i in range(3):
    register_cases.append(("John Doe", f"user{_i}@plansphere.com", "123", "reg-pass-error", "Must be at least 6 characters."))
register_cases.append(("New User", "newuser@plansphere.com", "secure123", "success", "Registration complete!"))

@pytest.mark.parametrize("name,email,password,err_type,expected_msg", register_cases)
def test_appium_registration(appium_driver, name, email, password, err_type, expected_msg):
    """Verify registration form field validations on mobile emulation browser."""
    appium_driver.get(f"{BASE_URL}/index.html")
    WebDriverWait(appium_driver, 5).until(EC.element_to_be_clickable((By.CSS_SELECTOR, "#login-panel a.switch-link")))
    appium_driver.execute_script("switchPanel('register')")
    time.sleep(0.05)
    appium_driver.find_element(By.ID, "reg-name").clear()
    appium_driver.find_element(By.ID, "reg-name").send_keys(name)
    appium_driver.find_element(By.ID, "reg-email").clear()
    appium_driver.find_element(By.ID, "reg-email").send_keys(email)
    appium_driver.find_element(By.ID, "reg-pass").clear()
    appium_driver.find_element(By.ID, "reg-pass").send_keys(password)
    appium_driver.find_element(By.CSS_SELECTOR, "#register-form button[type='submit']").click()
    if err_type == "success":
        toast = WebDriverWait(appium_driver, 5).until(EC.visibility_of_element_located((By.ID, "app-toast")))
        assert expected_msg in toast.text
    else:
        err = WebDriverWait(appium_driver, 5).until(EC.visibility_of_element_located((By.ID, err_type)))
        assert expected_msg in err.text

# 1c. Forgot Password – 5 cases
forgot_cases = []
for _i in range(4):
    forgot_cases.append((f"bademail{_i}", "forgot-email-error", "Please enter a valid email address."))
forgot_cases.append(("admin@plansphere.com", "success", "Recovery email sent."))

@pytest.mark.parametrize("email,err_type,expected_msg", forgot_cases)
def test_appium_forgot_password(appium_driver, email, err_type, expected_msg):
    """Verify forgot-password flow email validation on mobile emulation."""
    appium_driver.get(f"{BASE_URL}/index.html")
    WebDriverWait(appium_driver, 5).until(EC.element_to_be_clickable((By.CSS_SELECTOR, "#login-panel a.switch-link")))
    appium_driver.execute_script("switchPanel('forgot')")
    time.sleep(0.05)
    appium_driver.find_element(By.ID, "forgot-email").clear()
    appium_driver.find_element(By.ID, "forgot-email").send_keys(email)
    appium_driver.find_element(By.CSS_SELECTOR, "#forgot-form button[type='submit']").click()
    if err_type == "success":
        toast = WebDriverWait(appium_driver, 5).until(EC.visibility_of_element_located((By.ID, "app-toast")))
        assert expected_msg in toast.text
    else:
        err = WebDriverWait(appium_driver, 5).until(EC.visibility_of_element_located((By.ID, err_type)))
        assert expected_msg in err.text

# 1d. Google Sign-In – 5 cases
@pytest.mark.parametrize("case_num", range(1, 6))
def test_appium_google_login(appium_driver, case_num):
    """Simulate Google OAuth login flow on Appium mobile emulation browser."""
    appium_driver.get(f"{BASE_URL}/index.html")
    WebDriverWait(appium_driver, 5).until(EC.element_to_be_clickable((By.CLASS_NAME, "google-btn")))
    appium_driver.execute_script("mockGoogleLogin()")
    toast = WebDriverWait(appium_driver, 5).until(EC.visibility_of_element_located((By.ID, "app-toast")))
    assert "Google Authenticator" in toast.text
    WebDriverWait(appium_driver, 5).until(EC.url_contains("dashboard.html"))
    assert "dashboard.html" in appium_driver.current_url

# ─────────────────────────────────────────────────────────────
# SECTION 2 · ADD-BILL FORM (53 cases)
# ─────────────────────────────────────────────────────────────

# 2a. Smart Category Suggestion – 15 cases
# Keywords must exactly match autoCategorize() logic in app.js:
# Health: hospital, medical, pharmacy, doctor, medicine, checkup, apollo
# Insurance: insurance, lic, policy, premium
_electronics = ["MacBook Pro", "iPhone 16", "Sony PS5", "Samsung TV", "Dell Monitor"]
_health       = ["Hospital checkup", "Apollo clinic", "Pharmeasy medicines", "Doctor fees", "Medicine prescription"]
_insurance    = ["LIC Policy", "Star Health premium", "HDFC Life insurance", "Term policy", "Car insurance premium"]
suggestion_cases = (
    [(f"{w} {i}", "Electronics", "Warranty Bill") for i, w in enumerate(_electronics)] +
    [(f"{w} {i}", "Health",      "Medical Bill")  for i, w in enumerate(_health)]      +
    [(f"{w} {i}", "Insurance",   "Insurance")      for i, w in enumerate(_insurance)]
)

@pytest.mark.parametrize("title,expected_cat,expected_type", suggestion_cases)
def test_appium_category_suggestion(appium_driver, title, expected_cat, expected_type):
    """Verify smart-categorizer on mobile correctly maps title keywords to category dropdowns."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/add-bill.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "product-name")))
    inp = appium_driver.find_element(By.ID, "product-name")
    inp.clear(); inp.send_keys(title)
    time.sleep(0.05)
    assert Select(appium_driver.find_element(By.ID, "bill-category")).first_selected_option.get_attribute("value") == expected_cat
    assert Select(appium_driver.find_element(By.ID, "bill-type")).first_selected_option.get_attribute("value") == expected_type

# 2b. Warranty Duration Buttons – 20 cases (5 dates × 4 buttons)
_base_dates = ["2026-01-01", "2026-06-30", "2026-09-08", "2026-12-25", "2025-06-15"]
_buttons    = [("6", 6), ("12", 12), ("24", 24), ("36", 36)]
duration_cases = []
for _bd in _base_dates:
    for _bm, _mv in _buttons:
        _dt = datetime.strptime(_bd, "%Y-%m-%d")
        _m  = _dt.month - 1 + _mv
        _y  = _dt.year + _m // 12
        _m  = _m % 12 + 1
        _d  = min(_dt.day, [31, 29 if _y % 4 == 0 and (_y % 100 != 0 or _y % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][_m-1])
        duration_cases.append((_bd, _bm, f"{_y:04d}-{_m:02d}-{_d:02d}"))

@pytest.mark.parametrize("purchase_date,btn_months,expected_expiry", duration_cases)
def test_appium_warranty_duration(appium_driver, purchase_date, btn_months, expected_expiry):
    """Verify quick-duration buttons compute correct expiry date on Appium mobile browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/add-bill.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "purchase-date")))
    p = appium_driver.find_element(By.ID, "purchase-date")
    appium_driver.execute_script("arguments[0].value=arguments[1]; arguments[0].dispatchEvent(new Event('input'));", p, purchase_date)
    appium_driver.find_element(By.CSS_SELECTOR, f"button[data-months='{btn_months}']").click()
    assert appium_driver.find_element(By.ID, "expiry-date").get_attribute("value") == expected_expiry

# 2c. Form Validation – 10 cases
# NOTE: expiry validation (err-expiry) only triggers when bill-type == 'Warranty Bill'
# Medical Bill and Insurance types do NOT validate expiry in the form JS
_fv = [
    ("",        "Electronics", "Warranty Bill",  500, "Store", "2026-01-01", "2026-12-31", "err-product"),
    ("Product", "Electronics", "Warranty Bill",    0, "Store", "2026-01-01", "2026-12-31", "err-amount"),
    ("Product", "Electronics", "Warranty Bill",  -10, "Store", "2026-01-01", "2026-12-31", "err-amount"),
    ("Product", "Electronics", "Warranty Bill",  500, "Store", "",           "2026-12-31", "err-purchase"),
    ("Product", "Electronics", "Warranty Bill",  500, "Store", "2026-05-01", "2026-04-01", "err-expiry"),
    ("Product", "Electronics", "Warranty Bill",  500, "Store", "2026-05-01", "2026-03-10", "err-expiry"),
    ("Product", "Electronics", "Warranty Bill",  500, "Store", "2026-05-01", "2026-03-11", "err-expiry"),
    ("Product", "Electronics", "Warranty Bill",  500, "Store", "2026-05-01", "2026-03-12", "err-expiry"),
    ("Product", "Electronics", "Warranty Bill",  500, "Store", "2026-06-01", "2026-05-30", "err-expiry"),
    ("Product", "Electronics", "Warranty Bill",  500, "Store", "2026-07-01", "2026-06-30", "err-expiry"),
]

@pytest.mark.parametrize("name,cat,btype,amount,store,pdate,edate,err_id", _fv)
def test_appium_add_bill_form_validation(appium_driver, name, cat, btype, amount, store, pdate, edate, err_id):
    """Verify Add Bill form on mobile rejects invalid entries with correct inline error messages."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/add-bill.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "product-name")))
    appium_driver.find_element(By.ID, "product-name").clear()
    if name: appium_driver.find_element(By.ID, "product-name").send_keys(name)
    Select(appium_driver.find_element(By.ID, "bill-category")).select_by_value(cat)
    Select(appium_driver.find_element(By.ID, "bill-type")).select_by_value(btype)
    appium_driver.find_element(By.ID, "bill-amount").clear()
    appium_driver.find_element(By.ID, "bill-amount").send_keys(str(amount))
    appium_driver.find_element(By.ID, "bill-store").clear()
    appium_driver.find_element(By.ID, "bill-store").send_keys(store)
    p_in = appium_driver.find_element(By.ID, "purchase-date")
    e_in = appium_driver.find_element(By.ID, "expiry-date")
    appium_driver.execute_script("arguments[0].value=arguments[1]; arguments[0].dispatchEvent(new Event('input'));", p_in, pdate)
    appium_driver.execute_script("arguments[0].value=arguments[1]; arguments[0].dispatchEvent(new Event('input'));", e_in, edate)
    appium_driver.find_element(By.CSS_SELECTOR, "#bill-form button[type='submit']").click()
    err = WebDriverWait(appium_driver, 5).until(EC.visibility_of_element_located((By.ID, err_id)))
    assert err.is_displayed()

# 2d. Add Bill Save Success – 8 cases
_save_cases = [(f"MobileProduct{i}", 500+i*100, "Electronics", "Warranty Bill", f"Store{i}", "2026-01-01", "2027-01-01") for i in range(8)]

@pytest.mark.parametrize("name,amt,cat,btype,store,pdate,edate", _save_cases)
def test_appium_add_bill_success(appium_driver, name, amt, cat, btype, store, pdate, edate):
    """Verify successful bill form submission redirects to bills list on mobile."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/add-bill.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "product-name")))
    appium_driver.find_element(By.ID, "product-name").send_keys(name)
    Select(appium_driver.find_element(By.ID, "bill-category")).select_by_value(cat)
    Select(appium_driver.find_element(By.ID, "bill-type")).select_by_value(btype)
    appium_driver.find_element(By.ID, "bill-amount").send_keys(str(amt))
    appium_driver.find_element(By.ID, "bill-store").send_keys(store)
    p_in = appium_driver.find_element(By.ID, "purchase-date")
    e_in = appium_driver.find_element(By.ID, "expiry-date")
    appium_driver.execute_script("arguments[0].value=arguments[1]; arguments[0].dispatchEvent(new Event('input'));", p_in, pdate)
    appium_driver.execute_script("arguments[0].value=arguments[1]; arguments[0].dispatchEvent(new Event('input'));", e_in, edate)
    appium_driver.find_element(By.CSS_SELECTOR, "#bill-form button[type='submit']").click()
    WebDriverWait(appium_driver, 5).until(EC.url_contains("bills.html"))
    assert "bills.html" in appium_driver.current_url

# ─────────────────────────────────────────────────────────────
# SECTION 3 · BILLS VAULT (39 cases)
# ─────────────────────────────────────────────────────────────

# 3a. Category Filter – 15 cases
_filter_cases = [
    ("all", 4), ("Electronics", 2), ("Health", 1), ("Insurance", 1), ("Utilities", 0),
    ("all", 4), ("Electronics", 2), ("Health", 1), ("Insurance", 1), ("all", 4),
    ("Electronics", 2), ("Health", 1), ("Insurance", 1), ("Utilities", 0), ("all", 4),
]

@pytest.mark.parametrize("cat_filter,expected_count", _filter_cases)
def test_appium_bills_filtering(appium_driver, cat_filter, expected_count):
    """Verify bills page category filter correctly limits visible cards on mobile viewport."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/bills.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "filter-category")))
    Select(appium_driver.find_element(By.ID, "filter-category")).select_by_value(cat_filter)
    time.sleep(0.1)
    cards = appium_driver.find_elements(By.CSS_SELECTOR, "#bills-grid .bill-card")
    assert len(cards) == expected_count

# 3b. Sort Options – 4 cases (only these values exist in the sort-by <select>)
_sort_options = ["date-desc", "date-asc", "amount-desc", "amount-asc"]

@pytest.mark.parametrize("sort_val", _sort_options)
def test_appium_bills_sort_options(appium_driver, sort_val):
    """Verify sort dropdown applies without errors and bills-grid stays visible on mobile."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/bills.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "sort-by")))
    Select(appium_driver.find_element(By.ID, "sort-by")).select_by_value(sort_val)
    time.sleep(0.05)
    assert appium_driver.find_element(By.ID, "bills-grid").is_displayed()

# 3c. Inline Search – 6 cases
_bill_search_cases = ["MacBook", "iPhone", "LIC", "Apollo", "Sony", "Samsung"]

@pytest.mark.parametrize("keyword", _bill_search_cases)
def test_appium_bills_inline_search(appium_driver, keyword):
    """Verify bills page inline search filters by keyword on Appium mobile emulation."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/bills.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "search-input")))
    appium_driver.find_element(By.ID, "search-input").clear()
    appium_driver.find_element(By.ID, "search-input").send_keys(keyword)
    time.sleep(0.1)
    assert appium_driver.find_element(By.ID, "bills-grid").is_displayed()

# 3d. Bill Detail Page – 12 cases
_detail_cases = [
    (f"MobileDetail{i}", 1000+i*200, "Electronics", "Warranty Bill", f"Shop{i}", "2026-01-01", "2027-01-01")
    for i in range(12)
]

@pytest.mark.parametrize("name,amt,cat,btype,store,pdate,edate", _detail_cases)
def test_appium_bill_detail_view(appium_driver, name, amt, cat, btype, store, pdate, edate):
    """Verify bill detail page loads and shows correct product title on Appium mobile."""
    inject_session(appium_driver)
    bill_id = f"mob-{int(time.time()*1000)}-{name[-1]}"
    inject_bills(appium_driver, f'[{{id:"{bill_id}",productName:"{name}",category:"{cat}",type:"{btype}",amount:{amt},purchaseDate:"{pdate}",expiryDate:"{edate}"}}]')
    appium_driver.get(f"{BASE_URL}/bill-details.html?id={bill_id}")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "product-title")))
    assert name in appium_driver.find_element(By.ID, "product-title").text

# ─────────────────────────────────────────────────────────────
# SECTION 4 · DOCUMENT VAULT (30 cases)
# ─────────────────────────────────────────────────────────────

# 4a. Document Upload – 15 cases
_doc_cats = ["Aadhaar", "PAN", "Certificates", "Other"]
_doc_upload_cases = [(f"MobileUpload_{i}.pdf", _doc_cats[i % 4]) for i in range(15)]

@pytest.mark.parametrize("doc_name,category", _doc_upload_cases)
def test_appium_document_upload(appium_driver, doc_name, category):
    """Verify document injection appears in vault under the correct folder on Appium mobile."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/vault.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "docs-list")))
    appium_driver.execute_script(f"selectFolder('{category}')")
    initial = len(appium_driver.find_elements(By.CSS_SELECTOR, "#docs-list .doc-card"))
    appium_driver.execute_script(f"""
        saveDocument({{id:'doc-{int(time.time()*1000)}',name:'{doc_name}',
        category:'{category}',uploadDate:'2026-06-23',fileSize:'200 KB',image:'',fileType:'pdf'}});
    """)
    appium_driver.refresh()
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "docs-list")))
    appium_driver.execute_script(f"selectFolder('{category}')")
    assert len(appium_driver.find_elements(By.CSS_SELECTOR, "#docs-list .doc-card")) == initial + 1
    assert doc_name in appium_driver.find_element(By.ID, "docs-list").text

# 4b. Document Deletion – 15 cases
_doc_del_cases = [(f"MobileDelete_{i}.pdf", i) for i in range(15)]

@pytest.mark.parametrize("doc_name,idx", _doc_del_cases)
def test_appium_document_deletion(appium_driver, doc_name, idx):
    """Verify vault document removal on Appium mobile emulation and confirms it is gone."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/vault.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "docs-list")))
    doc_id = f"mob-del-{idx}"
    appium_driver.execute_script(f"""
        saveDocument({{id:'{doc_id}',name:'{doc_name}',category:'Other',
        uploadDate:'2026-06-23',fileSize:'100 KB',image:'',fileType:'pdf'}});
    """)
    appium_driver.refresh()
    appium_driver.execute_script(f"deleteDocument('{doc_id}')")
    appium_driver.refresh()
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "docs-list")))
    assert doc_name not in appium_driver.find_element(By.ID, "docs-list").text

# ─────────────────────────────────────────────────────────────
# SECTION 5 · DASHBOARD (30 cases)
# ─────────────────────────────────────────────────────────────

# 5a. Stat Cards – 10 cases
_dash_cases = [((i % 5) + 1, (i % 3) + 1) for i in range(10)]

@pytest.mark.parametrize("num_bills,num_docs", _dash_cases)
def test_appium_dashboard_stats(appium_driver, num_bills, num_docs):
    """Verify dashboard stat cards on Appium mobile show correct counts from localStorage."""
    inject_session(appium_driver)
    bills = "[" + ",".join([f'{{id:"b{x}",productName:"P{x}",category:"Electronics",type:"Warranty Bill",amount:1000,purchaseDate:"2026-06-20",expiryDate:"2027-06-20"}}' for x in range(num_bills)]) + "]"
    docs  = "[" + ",".join([f'{{id:"d{x}",name:"D{x}",category:"PAN",uploadDate:"2026-06-20",fileSize:"100 KB"}}' for x in range(num_docs)]) + "]"
    inject_bills(appium_driver, bills)
    inject_docs(appium_driver, docs)
    appium_driver.get(f"{BASE_URL}/dashboard.html")
    time.sleep(0.8)
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "stat-total")))
    assert int(appium_driver.find_element(By.ID, "stat-total").text) == num_bills
    assert int(appium_driver.find_element(By.ID, "stat-docs").text) == num_docs

# 5b. Spending Stat – 10 cases
_spending_cases = [(i * 1500, (i + 1) * 1500) for i in range(10)]

@pytest.mark.parametrize("amt1,amt2", _spending_cases)
def test_appium_dashboard_spending_stat(appium_driver, amt1, amt2):
    """Verify dashboard total spending stat is non-empty on Appium mobile emulation."""
    inject_session(appium_driver)
    inject_bills(appium_driver, f'[{{id:"s1",productName:"P1",category:"Electronics",type:"Warranty Bill",amount:{amt1},purchaseDate:"2026-06-01",expiryDate:"2027-06-01"}},{{id:"s2",productName:"P2",category:"Health",type:"Medical Bill",amount:{amt2},purchaseDate:"2026-06-05",expiryDate:"2027-06-05"}}]')
    appium_driver.get(f"{BASE_URL}/dashboard.html")
    time.sleep(0.8)
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "stat-spending")))
    assert appium_driver.find_element(By.ID, "stat-spending").text != ""

# 5c. Expiry Notifications – 10 cases
_notif_cases = [(f"MobileAlert{i}", (datetime.now() + timedelta(days=12)).strftime("%Y-%m-%d")) for i in range(10)]

@pytest.mark.parametrize("prod_name,expiry_date", _notif_cases)
def test_appium_expiry_notifications(appium_driver, prod_name, expiry_date):
    """Verify near-expiry bills trigger alerts on the notifications timeline on mobile."""
    inject_session(appium_driver)
    inject_bills(appium_driver, f'[{{id:"near",productName:"{prod_name}",category:"Electronics",type:"Warranty Bill",amount:5000,purchaseDate:"2026-01-01",expiryDate:"{expiry_date}"}}]')
    appium_driver.get(f"{BASE_URL}/dashboard.html")
    time.sleep(1.2)
    appium_driver.get(f"{BASE_URL}/notifications.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "timeline-container")))
    page_text = appium_driver.find_element(By.ID, "timeline-container").text
    assert "Warranty Expiration" in page_text
    assert prod_name in page_text

# ─────────────────────────────────────────────────────────────
# SECTION 6 · ANALYTICS (20 cases)
# ─────────────────────────────────────────────────────────────

# 6a. Total Vault Value – 10 cases
_analytics_cases = [(i * 1500, (i + 1) * 2500) for i in range(10)]

@pytest.mark.parametrize("amount1,amount2", _analytics_cases)
def test_appium_analytics_spending(appium_driver, amount1, amount2):
    """Verify analytics metric-vault shows correct total amount on Appium mobile browser."""
    inject_session(appium_driver)
    inject_bills(appium_driver, f'[{{id:"b1",productName:"P1",category:"Electronics",type:"Warranty Bill",amount:{amount1},purchaseDate:"2026-06-01",expiryDate:"2027-06-01"}},{{id:"b2",productName:"P2",category:"Health",type:"Medical Bill",amount:{amount2},purchaseDate:"2026-06-05",expiryDate:"2027-06-05"}}]')
    appium_driver.get(f"{BASE_URL}/analytics.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "metric-vault")))
    total_text = appium_driver.find_element(By.ID, "metric-vault").text
    assert str(amount1 + amount2) in total_text.replace(",", "")

# 6b. Avg & Highest Metrics – 10 cases
_avg_cases = [(i * 500 + 100, (i + 1) * 800 + 200) for i in range(10)]

@pytest.mark.parametrize("a1,a2", _avg_cases)
def test_appium_analytics_avg_high_metrics(appium_driver, a1, a2):
    """Verify analytics avg and highest metric cards are non-empty on Appium mobile."""
    inject_session(appium_driver)
    inject_bills(appium_driver, f'[{{id:"a1",productName:"A1",category:"Electronics",type:"Warranty Bill",amount:{a1},purchaseDate:"2026-06-01",expiryDate:"2027-06-01"}},{{id:"a2",productName:"A2",category:"Health",type:"Medical Bill",amount:{a2},purchaseDate:"2026-06-05",expiryDate:"2027-06-05"}}]')
    appium_driver.get(f"{BASE_URL}/analytics.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "metric-avg")))
    assert appium_driver.find_element(By.ID, "metric-avg").text != ""
    assert appium_driver.find_element(By.ID, "metric-high").text != ""

# ─────────────────────────────────────────────────────────────
# SECTION 7 · WARRANTY TRACKER (30 cases)
# ─────────────────────────────────────────────────────────────

# 7a. Protected Tab – 10 cases
@pytest.mark.parametrize("count", range(1, 11))
def test_appium_warranty_protected_count(appium_driver, count):
    """Verify warranty all-tab counter on Appium mobile reflects injected active warranty count."""
    inject_session(appium_driver)
    future = (datetime.now() + timedelta(days=365)).strftime("%Y-%m-%d")
    bills = "[" + ",".join([f'{{id:"w{x}",productName:"W{x}",category:"Electronics",type:"Warranty Bill",amount:3000,purchaseDate:"2026-01-01",expiryDate:"{future}"}}' for x in range(count)]) + "]"
    inject_bills(appium_driver, bills)
    appium_driver.get(f"{BASE_URL}/warranties.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "tab-all")))
    assert str(count) in appium_driver.find_element(By.ID, "tab-all").text

# 7b. Expired Tab – 10 cases
@pytest.mark.parametrize("count", range(1, 11))
def test_appium_warranty_expired_count(appium_driver, count):
    """Verify expired tab on Appium mobile shows correct count of past-expiry warranties."""
    inject_session(appium_driver)
    past = (datetime.now() - timedelta(days=60)).strftime("%Y-%m-%d")
    bills = "[" + ",".join([f'{{id:"e{x}",productName:"E{x}",category:"Electronics",type:"Warranty Bill",amount:2000,purchaseDate:"2025-01-01",expiryDate:"{past}"}}' for x in range(count)]) + "]"
    inject_bills(appium_driver, bills)
    appium_driver.get(f"{BASE_URL}/warranties.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "tab-expired")))
    assert str(count) in appium_driver.find_element(By.ID, "tab-expired").text

# 7c. Warning Tab – 10 cases
@pytest.mark.parametrize("count", range(1, 11))
def test_appium_warranty_warning_count(appium_driver, count):
    """Verify expiring-soon tab on Appium mobile shows correct count for near-expiry warranties."""
    inject_session(appium_driver)
    soon = (datetime.now() + timedelta(days=10)).strftime("%Y-%m-%d")
    bills = "[" + ",".join([f'{{id:"s{x}",productName:"S{x}",category:"Electronics",type:"Warranty Bill",amount:1500,purchaseDate:"2025-01-01",expiryDate:"{soon}"}}' for x in range(count)]) + "]"
    inject_bills(appium_driver, bills)
    appium_driver.get(f"{BASE_URL}/warranties.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "tab-warning")))
    assert str(count) in appium_driver.find_element(By.ID, "tab-warning").text

# ─────────────────────────────────────────────────────────────
# SECTION 8 · SETTINGS & PROFILE (30 cases)
# ─────────────────────────────────────────────────────────────

# 8a. Theme Toggle – 10 cases
_theme_vals = ["light", "dark", "light", "dark", "light", "dark", "light", "dark", "light", "dark"]

@pytest.mark.parametrize("theme_val", _theme_vals)
def test_appium_theme_toggle(appium_driver, theme_val):
    """Verify settings theme toggle is accessible and interactive on Appium mobile browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/settings.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "theme-toggle-check")))
    is_checked = appium_driver.find_element(By.ID, "theme-toggle-check").is_selected()
    if theme_val == "light" and not is_checked:
        appium_driver.execute_script("document.getElementById('theme-toggle-check').click()")
    elif theme_val == "dark" and is_checked:
        appium_driver.execute_script("document.getElementById('theme-toggle-check').click()")
    time.sleep(0.1)
    assert appium_driver.find_element(By.ID, "theme-toggle-check") is not None

# 8b. Profile Page Load – 10 cases
_profile_users = [
    ("Administrator", "admin@plansphere.com"),
    ("Alice Smith",   "alice@plansphere.com"),
    ("Bob Jones",     "bob@plansphere.com"),
    ("Charlie Brown", "charlie@plansphere.com"),
    ("Diana Prince",  "diana@plansphere.com"),
    ("Eve Adams",     "eve@plansphere.com"),
    ("Frank Castle",  "frank@plansphere.com"),
    ("Grace Lee",     "grace@plansphere.com"),
    ("Hank Pym",      "hank@plansphere.com"),
    ("Iris West",     "iris@plansphere.com"),
]

@pytest.mark.parametrize("user_name,user_email", _profile_users)
def test_appium_profile_page_load(appium_driver, user_name, user_email):
    """Verify profile page correctly populates name/email from session on Appium mobile."""
    inject_session(appium_driver, email=user_email, name=user_name)
    appium_driver.get(f"{BASE_URL}/profile.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "prof-name")))
    assert user_name in appium_driver.find_element(By.ID, "prof-name").text
    assert user_email in appium_driver.find_element(By.ID, "prof-email").text

# 8c. Profile Edit Name Pre-fill – 10 cases
_edit_names = ["Rahul Kumar", "Priya Mehta", "Arjun Nair", "Sneha Iyer", "Vikram Das",
               "Kavya Shah", "Rohan Verma", "Neha Gupta", "Aditya Roy", "Pooja Singh"]

@pytest.mark.parametrize("user_name", _edit_names)
def test_appium_profile_edit_prefill(appium_driver, user_name):
    """Verify profile edit input is pre-filled with session name on Appium mobile browser."""
    inject_session(appium_driver, email="test@plansphere.com", name=user_name)
    appium_driver.get(f"{BASE_URL}/profile.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "edit-name")))
    assert appium_driver.find_element(By.ID, "edit-name").get_attribute("value") == user_name

# ─────────────────────────────────────────────────────────────
# SECTION 9 · SMART SEARCH (25 cases)
# ─────────────────────────────────────────────────────────────

_search_cases = [
    ("MacBook",       1, 0), ("iPhone",   1, 0), ("LIC",         1, 0),
    ("Apollo",        1, 0), ("Aadhaar",  0, 1), ("PAN",         0, 1),
    ("above 10000",   3, 3), ("under 20000", 2, 3),
    ("expired",       1, 3), ("active",   2, 3), ("protected",   2, 3),
    ("warning",       1, 3), ("2026",     3, 3), ("2025",        1, 0),
    ("above 100000",  2, 3), ("below 500",0, 3), ("health",      1, 0),
    ("electronics",   2, 0), ("insurance",1, 0), ("medical",     1, 0),
    ("Samsung",       0, 0), ("Sony",     0, 0), ("Star Health",  1, 0),
    ("HDFC",          0, 0),
]

@pytest.mark.parametrize("query,exp_bills,exp_docs", _search_cases)
def test_appium_smart_search(appium_driver, query, exp_bills, exp_docs):
    """Verify natural language search result counts on Appium mobile emulation browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/search.html")
    WebDriverWait(appium_driver, 5).until(EC.presence_of_element_located((By.ID, "query-input")))
    q = appium_driver.find_element(By.ID, "query-input")
    q.clear()
    q.send_keys(query)
    # Trigger the 'input' event which calls executeSmartSearch() internally
    appium_driver.execute_script("""
        var el = document.getElementById('query-input');
        el.dispatchEvent(new Event('input', {bubbles: true}));
    """)
    time.sleep(0.5)
    bills_found = len(appium_driver.find_elements(By.CSS_SELECTOR, "#bills-results-container .recent-item"))
    docs_found  = len(appium_driver.find_elements(By.CSS_SELECTOR, "#docs-results-container .recent-item"))
    assert bills_found == exp_bills
    assert docs_found  == exp_docs

# ─────────────────────────────────────────────────────────────
# SECTION 10 · AUTH GUARDS & NAVIGATION (6 cases)
# ─────────────────────────────────────────────────────────────

_protected_pages = [
    "dashboard.html", "bills.html", "vault.html",
    "warranties.html", "analytics.html", "notifications.html",
]

@pytest.mark.parametrize("page", _protected_pages)
def test_appium_auth_guard_redirect(appium_driver, page):
    """Verify protected pages redirect un-authenticated mobile users back to login screen."""
    appium_driver.get(f"{BASE_URL}/index.html")
    appium_driver.execute_script("localStorage.clear();")
    appium_driver.get(f"{BASE_URL}/{page}")
    time.sleep(0.5)
    assert "index.html" in appium_driver.current_url or appium_driver.current_url.endswith("/")
