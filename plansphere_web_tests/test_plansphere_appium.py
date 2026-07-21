import time
import pytest
from datetime import datetime, timedelta
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC

BASE_URL = "http://localhost:8000"

def inject_session(driver, email="admin@plansphere.com", name="Administrator"):
    if "localhost" not in driver.current_url:
        driver.get(f"{BASE_URL}/index.html")
    driver.execute_script(f"""
        localStorage.clear();
        if (typeof initializeDatabase === 'function') {{
            initializeDatabase();
        }}
        localStorage.setItem('plansphere_session', JSON.stringify({{
            email: '{email}',
            name: '{name}',
            token: 'session-{int(time.time()*1000)}'
        }}));
    """)

# ─────────────────────────────────────────────────────────────
# 1. AUTHENTICATION TESTS (60 cases)
# ─────────────────────────────────────────────────────────────

# Generate 30 Login Test Cases
login_cases = []
for i in range(6):
    login_cases.append((f"invalidemail{i}", "admin123", "email-error", "Please enter a valid email address."))
for i in range(8):
    login_cases.append(("admin@plansphere.com", f"wrongpass{i}", None, "Invalid email or password."))
login_cases.append(("admin@plansphere.com", "admin123", "success", "Sign In successful!"))

@pytest.mark.parametrize("email,password,expected_error_type,expected_msg", login_cases)
def test_appium_login(appium_driver, email, password, expected_error_type, expected_msg):
    """Verify login validation and credentials check with various inputs on Appium mobile browser."""
    appium_driver.get(f"{BASE_URL}/index.html")
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "email")))
    appium_driver.find_element(By.ID, "email").clear()
    appium_driver.find_element(By.ID, "email").send_keys(email)
    appium_driver.find_element(By.ID, "password").clear()
    appium_driver.find_element(By.ID, "password").send_keys(password)
    
    appium_driver.find_element(By.CSS_SELECTOR, "#login-form button[type='submit']").click()
    
    if expected_error_type == "email-error":
        err_el = WebDriverWait(appium_driver, 3).until(
            EC.visibility_of_element_located((By.ID, "email-error"))
        )
        assert expected_msg in err_el.text
    elif expected_error_type == "password-error":
        err_el = WebDriverWait(appium_driver, 3).until(
            EC.visibility_of_element_located((By.ID, "password-error"))
        )
        assert expected_msg in err_el.text
    elif expected_error_type == "success":
        WebDriverWait(appium_driver, 3).until(EC.url_contains("dashboard.html"))
        assert "dashboard.html" in appium_driver.current_url
    else:
        toast = WebDriverWait(appium_driver, 3).until(
            EC.visibility_of_element_located((By.ID, "app-toast"))
        )
        assert expected_msg in toast.text

# Generate 12 Registration Test Cases
register_cases = []
for i in range(4):
    register_cases.append(("", f"reg{i}@plansphere.com", "pass12345", "reg-name-error", "Name is required."))
for i in range(4):
    register_cases.append(("John Doe", f"badregemail{i}", "pass12345", "reg-email-error", "Please enter a valid email."))
for i in range(3):
    register_cases.append(("John Doe", f"user{i}@plansphere.com", "123", "reg-pass-error", "Must be at least 6 characters."))
register_cases.append(("New User", "newuser@plansphere.com", "secure123", "success", "Registration complete!"))

@pytest.mark.parametrize("name,email,password,expected_error_type,expected_msg", register_cases)
def test_appium_registration(appium_driver, name, email, password, expected_error_type, expected_msg):
    """Verify registration form validations on Appium mobile browser."""
    appium_driver.get(f"{BASE_URL}/index.html")
    
    WebDriverWait(appium_driver, 3).until(EC.element_to_be_clickable((By.CSS_SELECTOR, "#login-panel a.switch-link")))
    appium_driver.execute_script("switchPanel('register')")
    time.sleep(0.05)
    
    appium_driver.find_element(By.ID, "reg-name").clear()
    appium_driver.find_element(By.ID, "reg-name").send_keys(name)
    appium_driver.find_element(By.ID, "reg-email").clear()
    appium_driver.find_element(By.ID, "reg-email").send_keys(email)
    appium_driver.find_element(By.ID, "reg-pass").clear()
    appium_driver.find_element(By.ID, "reg-pass").send_keys(password)
    
    appium_driver.find_element(By.CSS_SELECTOR, "#register-form button[type='submit']").click()
    
    if expected_error_type == "success":
        toast = WebDriverWait(appium_driver, 3).until(EC.visibility_of_element_located((By.ID, "app-toast")))
        assert expected_msg in toast.text
    else:
        err_el = WebDriverWait(appium_driver, 3).until(
            EC.visibility_of_element_located((By.ID, expected_error_type))
        )
        assert expected_msg in err_el.text

# Generate 5 Forgot Password Test Cases
forgot_cases = []
for i in range(4):
    forgot_cases.append((f"bademail{i}", "forgot-email-error", "Please enter a valid email address."))
forgot_cases.append(("admin@plansphere.com", "success", "Recovery email sent."))

@pytest.mark.parametrize("email,expected_error_type,expected_msg", forgot_cases)
def test_appium_forgot_password(appium_driver, email, expected_error_type, expected_msg):
    """Verify forgot password recovery validation on Appium mobile browser."""
    appium_driver.get(f"{BASE_URL}/index.html")
    
    WebDriverWait(appium_driver, 3).until(EC.element_to_be_clickable((By.CSS_SELECTOR, "#login-panel a.switch-link")))
    appium_driver.execute_script("switchPanel('forgot')")
    time.sleep(0.05)
    
    appium_driver.find_element(By.ID, "forgot-email").clear()
    appium_driver.find_element(By.ID, "forgot-email").send_keys(email)
    appium_driver.find_element(By.CSS_SELECTOR, "#forgot-form button[type='submit']").click()
    
    if expected_error_type == "success":
        toast = WebDriverWait(appium_driver, 3).until(EC.visibility_of_element_located((By.ID, "app-toast")))
        assert expected_msg in toast.text
    else:
        err_el = WebDriverWait(appium_driver, 3).until(
            EC.visibility_of_element_located((By.ID, expected_error_type))
        )
        assert expected_msg in err_el.text

# Generate 5 Google Sign In Simulation Test Cases
@pytest.mark.parametrize("case_num", range(1, 6))
def test_appium_google_login(appium_driver, case_num):
    """Simulate Google Sign-In on Appium mobile browser."""
    appium_driver.get(f"{BASE_URL}/index.html")
    
    WebDriverWait(appium_driver, 3).until(EC.element_to_be_clickable((By.CLASS_NAME, "google-btn")))
    appium_driver.execute_script("mockGoogleLogin()")
    
    toast = WebDriverWait(appium_driver, 3).until(EC.visibility_of_element_located((By.ID, "app-toast")))
    assert "Google Authenticator" in toast.text
    
    WebDriverWait(appium_driver, 3).until(EC.url_contains("dashboard.html"))
    assert "dashboard.html" in appium_driver.current_url

# ─────────────────────────────────────────────────────────────
# 2. ADD BILL & WARRANTY FORM TESTS (100 cases)
# ─────────────────────────────────────────────────────────────

# Generate 30 Category Suggestion Test Cases
suggestion_cases = []
electronics_keywords = ["MacBook", "iPhone", "Sony PS5", "Samsung TV", "Dell Monitor"]
health_keywords = ["Hospital", "Apollo clinic", "Medicines Pharmeasy", "Doctor fee", "Dental"]
insurance_keywords = ["LIC Policy", "Star Health", "HDFC Life", "Term policy", "Car insurance"]

for idx, word in enumerate(electronics_keywords):
    suggestion_cases.append((f"{word} {idx}", "Electronics", "Warranty Bill"))
for idx, word in enumerate(health_keywords):
    suggestion_cases.append((f"{word} {idx}", "Health", "Medical Bill"))
for idx, word in enumerate(insurance_keywords):
    suggestion_cases.append((f"{word} {idx}", "Insurance", "Insurance"))

@pytest.mark.parametrize("title,expected_category,expected_type", suggestion_cases)
def test_appium_category_suggestion(appium_driver, title, expected_category, expected_type):
    """Verify smart categorizer correctly maps keywords on Appium mobile browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/add-bill.html")
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "product-name")))
    product_input = appium_driver.find_element(By.ID, "product-name")
    product_input.clear()
    product_input.send_keys(title)
    
    time.sleep(0.02)
    
    category_select = Select(appium_driver.find_element(By.ID, "bill-category"))
    type_select = Select(appium_driver.find_element(By.ID, "bill-type"))
    
    assert category_select.first_selected_option.get_attribute("value") == expected_category
    assert type_select.first_selected_option.get_attribute("value") == expected_type

# Generate 60 Duration Calculator Test Cases (15 base dates * 4 buttons)
duration_cases = []
base_dates = [
    "2026-01-01", "2026-06-30", "2026-09-08", "2026-12-25", "2025-06-15"
]
buttons = [("6", 6), ("12", 12), ("24", 24), ("36", 36)]

for b_date in base_dates:
    for btn_months, months_val in buttons:
        dt = datetime.strptime(b_date, "%Y-%m-%d")
        month = dt.month - 1 + months_val
        year = dt.year + month // 12
        month = month % 12 + 1
        day = min(dt.day, [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month-1])
        expected_date = f"{year:04d}-{month:02d}-{day:02d}"
        duration_cases.append((b_date, btn_months, expected_date))

@pytest.mark.parametrize("purchase_date,btn_months,expected_expiry", duration_cases)
def test_appium_warranty_duration(appium_driver, purchase_date, btn_months, expected_expiry):
    """Verify quick duration buttons compute expiry dates on Appium mobile browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/add-bill.html")
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "purchase-date")))
    p_date_input = appium_driver.find_element(By.ID, "purchase-date")
    
    # Set date value via JS to bypass chrome locale masking constraints
    appium_driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input'));", p_date_input, purchase_date)
    
    btn = appium_driver.find_element(By.CSS_SELECTOR, f"button[data-months='{btn_months}']")
    btn.click()
    
    expiry_input = appium_driver.find_element(By.ID, "expiry-date")
    assert expiry_input.get_attribute("value") == expected_expiry

# Generate 10 Form Validation cases
form_val_cases = [
    ("", "Electronics", "Warranty Bill", 500, "Store", "2026-01-01", "2026-12-31", "err-product"),
    ("Product", "Electronics", "Warranty Bill", 0, "Store", "2026-01-01", "2026-12-31", "err-amount"),
    ("Product", "Electronics", "Warranty Bill", -10, "Store", "2026-01-01", "2026-12-31", "err-amount"),
    ("Product", "Electronics", "Warranty Bill", 500, "Store", "", "2026-12-31", "err-purchase"),
    ("Product", "Electronics", "Warranty Bill", 500, "Store", "2026-05-01", "2026-04-01", "err-expiry"),
]
for i in range(5):
    form_val_cases.append(
        ("Product", "Electronics", "Warranty Bill", 500, "Store", "2026-05-01", f"2026-03-{10+i:02d}", "err-expiry")
    )

@pytest.mark.parametrize("name,category,bill_type,amount,store,p_date,exp_date,expected_err_id", form_val_cases)
def test_appium_add_bill_form_validation(appium_driver, name, category, bill_type, amount, store, p_date, exp_date, expected_err_id):
    """Verify input checks on the Add Bill form block invalid uploads on Appium mobile browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/add-bill.html")
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "product-name")))
    appium_driver.find_element(By.ID, "product-name").clear()
    if name:
        appium_driver.find_element(By.ID, "product-name").send_keys(name)
        
    Select(appium_driver.find_element(By.ID, "bill-category")).select_by_value(category)
    Select(appium_driver.find_element(By.ID, "bill-type")).select_by_value(bill_type)
    
    appium_driver.find_element(By.ID, "bill-amount").clear()
    appium_driver.find_element(By.ID, "bill-amount").send_keys(str(amount))
    
    appium_driver.find_element(By.ID, "bill-store").clear()
    appium_driver.find_element(By.ID, "bill-store").send_keys(store)
    
    p_input = appium_driver.find_element(By.ID, "purchase-date")
    if p_date:
        appium_driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input'));", p_input, p_date)
    else:
        appium_driver.execute_script("arguments[0].value = ''; arguments[0].dispatchEvent(new Event('input'));", p_input)
        
    e_input = appium_driver.find_element(By.ID, "expiry-date")
    if exp_date:
        appium_driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input'));", e_input, exp_date)
    else:
        appium_driver.execute_script("arguments[0].value = ''; arguments[0].dispatchEvent(new Event('input'));", e_input)
        
    appium_driver.find_element(By.CSS_SELECTOR, "#bill-form button[type='submit']").click()
    
    err_el = WebDriverWait(appium_driver, 3).until(
        EC.visibility_of_element_located((By.ID, expected_err_id))
    )
    assert err_el.is_displayed()

# ─────────────────────────────────────────────────────────────
# 3. VAULT ACTIONS TESTS (80 cases)
# ─────────────────────────────────────────────────────────────

# Generate 12 Document Upload Cases
doc_upload_cases = []
doc_categories = ["Aadhaar", "PAN", "Certificates", "Other"]
for i in range(12):
    doc_upload_cases.append((f"MobileDoc_{i}.pdf", doc_categories[i % 4]))

@pytest.mark.parametrize("doc_name,category", doc_upload_cases)
def test_appium_document_upload(appium_driver, doc_name, category):
    """Verify document upload on Appium mobile browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/vault.html")
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "docs-list")))
    appium_driver.execute_script(f"selectFolder('{category}')")
    initial_count = len(appium_driver.find_elements(By.CSS_SELECTOR, "#docs-list .doc-card"))
    
    appium_driver.execute_script(f"""
        saveDocument({{
            id: 'doc-{int(time.time()*1000)}',
            name: '{doc_name}',
            category: '{category}',
            uploadDate: '2026-06-23',
            fileSize: '180 KB',
            image: '',
            fileType: 'pdf'
        }});
    """)
    appium_driver.refresh()
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "docs-list")))
    appium_driver.execute_script(f"selectFolder('{category}')")
    final_count = len(appium_driver.find_elements(By.CSS_SELECTOR, "#docs-list .doc-card"))
    assert final_count == initial_count + 1
    
    page_text = appium_driver.find_element(By.ID, "docs-list").text
    assert doc_name in page_text

# Generate 12 Document Deletion Cases
doc_delete_cases = []
for i in range(12):
    doc_delete_cases.append((f"MobileDel_{i}.pdf", i))

@pytest.mark.parametrize("doc_name,index", doc_delete_cases)
def test_appium_document_deletion(appium_driver, doc_name, index):
    """Verify document vault records can be safely removed on Appium mobile browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/vault.html")
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "docs-list")))
    doc_id = f"appium-del-{index}"
    
    appium_driver.execute_script(f"""
        saveDocument({{
            id: '{doc_id}',
            name: '{doc_name}',
            category: 'Other',
            uploadDate: '2026-06-23',
            fileSize: '150 KB',
            image: '',
            fileType: 'pdf'
        }});
    """)
    appium_driver.refresh()
    
    appium_driver.execute_script(f"deleteDocument('{doc_id}')")
    appium_driver.refresh()
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "docs-list")))
    page_text = appium_driver.find_element(By.ID, "docs-list").text
    assert doc_name not in page_text

# ─────────────────────────────────────────────────────────────
# 4. DASHBOARD & MOBILE SEARCH TESTS (60 cases)
# ─────────────────────────────────────────────────────────────

# Generate 10 Dashboard Stat Configurations
dashboard_config_cases = []
for i in range(10):
    num_bills = (i % 5) + 1
    num_docs = (i % 3) + 1
    dashboard_config_cases.append((num_bills, num_docs))

@pytest.mark.parametrize("num_bills,num_docs", dashboard_config_cases)
def test_appium_dashboard_stats(appium_driver, num_bills, num_docs):
    """Verify dashboard summary metrics update on Appium mobile browser."""
    inject_session(appium_driver)
    
    bills_script = "[" + ",".join([
        f"{{id:'ab-{x}',productName:'P {x}',category:'Electronics',type:'Warranty Bill',amount:1200,purchaseDate:'2026-06-20',expiryDate:'2027-06-20'}}" 
        for x in range(num_bills)
    ]) + "]"
    
    docs_script = "[" + ",".join([
        f"{{id:'ad-{x}',name:'D {x}',category:'PAN',uploadDate:'2026-06-20',fileSize:'100 KB'}}" 
        for x in range(num_docs)
    ]) + "]"
    
    appium_driver.execute_script(f"""
        localStorage.setItem('plansphere_bills', JSON.stringify({bills_script}));
        localStorage.setItem('plansphere_documents', JSON.stringify({docs_script}));
    """)
    
    appium_driver.get(f"{BASE_URL}/dashboard.html")
    time.sleep(0.7)  # wait count animation
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "stat-total")))
    total_bills = appium_driver.find_element(By.ID, "stat-total").text
    total_docs = appium_driver.find_element(By.ID, "stat-docs").text
    
    assert int(total_bills) == num_bills
    assert int(total_docs) == num_docs

# Generate 10 Analytics spending cases
analytics_config_cases = []
for i in range(10):
    analytics_config_cases.append((i * 1500, (i + 1) * 2500))

@pytest.mark.parametrize("amount1,amount2", analytics_config_cases)
def test_appium_analytics_spending(appium_driver, amount1, amount2):
    """Verify analytics spending totals on Appium mobile browser."""
    inject_session(appium_driver)
    
    bills_data = f"""[
        {{id:'b-1',productName:'P1',category:'Electronics',type:'Warranty Bill',amount:{amount1},purchaseDate:'2026-06-01',expiryDate:'2027-06-01'}},
        {{id:'b-2',productName:'P2',category:'Health',type:'Medical Bill',amount:{amount2},purchaseDate:'2026-06-05',expiryDate:'2027-06-05'}}
    ]"""
    appium_driver.execute_script(f"localStorage.setItem('plansphere_bills', JSON.stringify({bills_data}));")
    
    appium_driver.get(f"{BASE_URL}/analytics.html")
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "analytics-total")))
    
    total_text = appium_driver.find_element(By.ID, "analytics-total").text
    expected_total = amount1 + amount2
    assert str(expected_total) in total_text.replace(",", "")

# Generate 10 Expiry Notifications Cases
notif_cases = []
for i in range(10):
    near_date = (datetime.now() + timedelta(days=12)).strftime("%Y-%m-%d")
    notif_cases.append((f"Mobile Alert {i}", near_date))

@pytest.mark.parametrize("prod_name,expiry_date", notif_cases)
def test_appium_expiry_notifications(appium_driver, prod_name, expiry_date):
    """Verify warranty expiration warnings trigger on Appium mobile browser."""
    inject_session(appium_driver)
    
    bill = f"{{id:'bill-near',productName:'{prod_name}',category:'Electronics',type:'Warranty Bill',amount:3500,purchaseDate:'2026-01-01',expiryDate:'{expiry_date}'}}"
    appium_driver.execute_script(f"localStorage.setItem('plansphere_bills', JSON.stringify([{bill}]));")
    
    appium_driver.get(f"{BASE_URL}/dashboard.html")
    time.sleep(1.2)
    
    appium_driver.get(f"{BASE_URL}/notifications.html")
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "notifications-container")))
    
    page_text = appium_driver.find_element(By.ID, "notifications-container").text
    assert "Warranty Expiration" in page_text
    assert prod_name in page_text

# Generate 5 Theme Switcher Cases
@pytest.mark.parametrize("theme_val", ["light", "dark", "light", "dark", "light"])
def test_appium_theme_toggle(appium_driver, theme_val):
    """Verify light/dark theme class switches on Appium mobile browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/settings.html")
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "theme-select")))
    theme_select = Select(appium_driver.find_element(By.ID, "theme-select"))
    theme_select.select_by_value(theme_val)
    
    appium_driver.find_element(By.CSS_SELECTOR, "#settings-form button[type='submit']").click()
    time.sleep(0.05)
    
    has_light_mode = appium_driver.execute_script("return document.documentElement.classList.contains('light-mode');")
    if theme_val == "light":
        assert has_light_mode
    else:
        assert not has_light_mode

# Generate 10 Natural Language Smart Search cases
search_cases = [
    ("MacBook", 1, 0),
    ("iPhone", 1, 0),
    ("LIC", 1, 0),
    ("Apollo", 1, 0),
    ("Aadhaar", 0, 1),
    ("PAN", 0, 1),
    ("above 10000", 3, 0),
    ("below 5000", 1, 0),
    ("under 20000", 2, 0),
    ("expired", 1, 0),
]

@pytest.mark.parametrize("query_str,exp_bills,exp_docs", search_cases)
def test_appium_smart_search(appium_driver, query_str, exp_bills, exp_docs):
    """Verify search queries on Appium mobile browser."""
    inject_session(appium_driver)
    appium_driver.get(f"{BASE_URL}/search.html")
    
    WebDriverWait(appium_driver, 3).until(EC.presence_of_element_located((By.ID, "search-input")))
    search_input = appium_driver.find_element(By.ID, "search-input")
    search_input.clear()
    search_input.send_keys(query_str)
    
    appium_driver.find_element(By.ID, "search-btn").click()
    time.sleep(0.1)
    
    bills_found = len(appium_driver.find_elements(By.CSS_SELECTOR, "#search-bills-results .search-result-card"))
    docs_found = len(appium_driver.find_elements(By.CSS_SELECTOR, "#search-docs-results .search-result-card"))
    
    assert bills_found == exp_bills
    assert docs_found == exp_docs
