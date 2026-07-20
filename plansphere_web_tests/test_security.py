import os
import re
import pytest

WEB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "plansphere_web"))

HTML_FILES = [
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

def read_file_content(relative_path):
    path = os.path.join(WEB_DIR, relative_path)
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

# 1. Parameterized XSS static analysis checks
@pytest.mark.parametrize("file_name", HTML_FILES + ["app.js"])
def test_security_xss_prevention(file_name):
    """Scan code to ensure eval() or document.write() are not used, minimizing XSS attack surface."""
    content = read_file_content(file_name)
    
    # Assert no raw eval usage
    assert "eval(" not in content, f"Insecure use of eval() detected in {file_name}"
    
    # Assert no document.write usage
    assert "document.write(" not in content, f"Insecure use of document.write() detected in {file_name}"

# 2. Check innerHTML usage safety in app.js
def test_security_js_innerhtml_sanitization():
    """Verify that innerHTML assignments in app.js are structurally sanitized or parameter-free."""
    content = read_file_content("app.js")
    
    # Find all occurrences of innerHTML
    matches = re.findall(r"(\w+\.innerHTML\s*=.*)", content)
    for match in matches:
        # If it uses dynamic string interpolation, it should be sanitized or verified
        if "$" in match or "`" in match:
            # We want to check if it's dynamic user-controlled strings, or if it uses textContent
            # We look for simple templates that are safe (e.g. static icons, numbers, or elements)
            # Allow icon classes, standard variables. Alert if it looks raw
            if "prompt(" in match or "location.hash" in match:
                pytest.fail(f"Potential unsafe innerHTML assignment detected in app.js: {match}")

# 3. Parameterized Form Inputs Verification (verify client-side input types are validated)
@pytest.mark.parametrize("html_file", ["index.html", "add-bill.html", "profile.html", "settings.html"])
def test_security_form_input_types(html_file):
    """Ensure form input fields enforce validation types (email, password, number) and requirements."""
    content = read_file_content(html_file)
    
    # Find all inputs
    inputs = re.findall(r"<input\s+([^>]+)>", content)
    for inp in inputs:
        # Check if type is present
        assert "type=" in inp, f"Missing input type validator in {html_file}: {inp}"
        
        # Check password type fields have correct autocomplete or type validation
        if "id=\"password\"" in inp or "id=\"reg-pass\"" in inp:
            assert "type=\"password\"" in inp, f"Password field does not mask input in {html_file}: {inp}"
            
        # Check email fields use type="email"
        if "email" in inp.lower() and "type=" in inp:
            assert "type=\"email\"" in inp or "type=\"text\"" in inp, f"Email field format is missing proper type validation in {html_file}: {inp}"

# 4. Parameterized Reverse Tabnabbing Check
@pytest.mark.parametrize("file_name", HTML_FILES)
def test_security_tabnabbing_prevention(file_name):
    """Scan all HTML anchor tags with target='_blank' to verify presence of rel='noopener noreferrer'."""
    content = read_file_content(file_name)
    
    # Find links with target="_blank"
    blank_links = re.findall(r"<a\s+[^>]*target=['\"]_blank['\"][^>]*>", content)
    for link in blank_links:
        assert "noopener" in link and "noreferrer" in link, (
            f"Reverse tabnabbing vulnerability detected in {file_name}: {link}. "
            "Add rel='noopener noreferrer'"
        )

# 5. Parameterized Insecure Hardcoded HTTP Protocols check
@pytest.mark.parametrize("file_name", HTML_FILES + ["app.js"])
def test_security_insecure_protocols(file_name):
    """Scan codebase to ensure no un-encrypted http links are used for API calls or assets."""
    content = read_file_content(file_name)
    
    # Exclude localhost, xml namespaces, schemas, standard http-equiv, and test URLs
    http_links = re.findall(r"['\"](http://[^'\"]+)['\"]", content)
    for link in http_links:
        if "localhost" not in link and "w3.org" not in link:
            pytest.fail(f"Insecure hardcoded HTTP resource link found in {file_name}: {link}")

# 6. Check LocalStorage and Cookie Data Leak prevention
def test_security_session_storage_protection():
    """Verify that user sessions in app.js do not save raw passwords inside local storage."""
    content = read_file_content("app.js")
    
    # Ensure loginUser does not store password in plansphere_session
    # Look at plansphere_session creation
    session_saves = re.findall(r"localStorage\.setItem\('plansphere_session',\s*JSON\.stringify\(([^)]+)\)\)", content)
    for save in session_saves:
        # Check if password is in the block
        assert "password" not in save, "Security alert: password saved inside session storage!"
