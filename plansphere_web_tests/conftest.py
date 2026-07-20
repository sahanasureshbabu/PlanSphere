import os
import time
import pytest
from datetime import datetime
from selenium import webdriver as selenium_webdriver
from selenium.webdriver.chrome.options import Options as SeleniumOptions
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

# Try Appium imports
try:
    from appium import webdriver as appium_webdriver
    from appium.options.common import AppiumOptions
    APPIUM_AVAILABLE = True
except ImportError:
    APPIUM_AVAILABLE = False

# List to gather all test execution results
test_results = []

@pytest.fixture(scope="session")
def driver():
    """Session-scoped headless Chrome WebDriver for Desktop E2E tests."""
    options = SeleniumOptions()
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    
    driver = selenium_webdriver.Chrome(options=options)
    driver.implicitly_wait(3)
    
    yield driver
    
    driver.quit()

@pytest.fixture(scope="session")
def appium_driver():
    """Session-scoped Appium mobile emulation driver."""
    options_loaded = False
    if APPIUM_AVAILABLE:
        try:
            options = AppiumOptions()
            options.set_capability("platformName", "linux")
            options.set_capability("browserName", "Chrome")
            options.set_capability("automationName", "Chromium")
            options.set_capability("goog:chromeOptions", {
                "args": ["--headless=new", "--no-sandbox", "--disable-dev-shm-usage"]
            })
            driver = appium_webdriver.Remote("http://localhost:4723", options=options)
            driver.implicitly_wait(3)
            options_loaded = True
            print("\nConnected to Appium Server on port 4723.")
            yield driver
            driver.quit()
        except Exception as e:
            print(f"\nAppium connection failed: {e}. Falling back to Chrome Mobile Emulation...")
            
    if not options_loaded:
        # Fallback: Use standard ChromeDriver with mobile emulation capabilities
        options = SeleniumOptions()
        options.add_argument("--headless=new")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu")
        options.add_argument("--window-size=375,812") # mobile resolution
        options.add_experimental_option("mobileEmulation", {
            "deviceMetrics": {"width": 375, "height": 812, "pixelRatio": 3.0},
            "userAgent": "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1"
        })
        driver = selenium_webdriver.Chrome(options=options)
        driver.implicitly_wait(3)
        print("Initialized Chrome mobile emulation driver (Appium fallback).")
        yield driver
        driver.quit()

@pytest.fixture(autouse=True)
def test_setup_cleanup(request):
    """Automatically runs before and after each test case to clean and reset state."""
    yield
    
    # Post-test state clean
    for driver_fixture in ["driver", "appium_driver"]:
        if driver_fixture in request.fixturenames:
            try:
                driver = request.getfixturevalue(driver_fixture)
                driver.execute_script("""
                    localStorage.clear();
                    if (typeof initializeDatabase === 'function') {
                        initializeDatabase();
                    }
                """)
            except Exception:
                pass

@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Intercepts pytest test status outcomes to build the E2E Excel report."""
    outcome = yield
    rep = outcome.get_result()
    
    if rep.when == "call" or (rep.when == "setup" and rep.failed):
        test_name = item.name
        docstring = item.obj.__doc__ or ""
        docstring = " ".join([line.strip() for line in docstring.split("\n") if line.strip()])
        
        description = docstring
        if hasattr(item, "callspec") and item.callspec:
            params_str = ", ".join(f"{k}={v}" for k, v in item.callspec.params.items())
            if description:
                description += f" (Parameters: {params_str})"
            else:
                description = f"Tested with parameters: {params_str}"
                
        if not description:
            description = "E2E functional verification case."
            
        status = rep.outcome.upper()  # PASSED, FAILED, SKIPPED
        duration = rep.duration
        
        error_msg = ""
        if rep.failed:
            error_msg = str(rep.longreprtext)
            
        # Parse Module from test class or function prefix
        module_name = "Core"
        if "_" in test_name:
            parts = test_name.split("_")
            if len(parts) > 1 and parts[1] not in ["test", "case"]:
                module_name = parts[1].capitalize()
                
        # Determine framework type (Appium vs Selenium)
        framework = "Selenium (Desktop)"
        if "appium" in test_name or "appium" in item.nodeid:
            framework = "Appium (Mobile Web)"
            
        test_results.append({
            "name": test_name,
            "framework": framework,
            "module": module_name,
            "description": description,
            "status": status,
            "duration": duration,
            "error": error_msg
        })

def pytest_sessionfinish(session, exitstatus):
    """Executes at the end of the test run to write the openpyxl Excel report."""
    workspace_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    report_path = os.path.join(workspace_dir, "selenium_test_report.xlsx")
    
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "E2E Execution Report"
    
    # Enable grid lines visibility
    ws.views.sheetView[0].showGridLines = True
    
    # Styles Definition
    navy_fill = PatternFill(start_color="1F2937", end_color="1F2937", fill_type="solid")
    header_fill = PatternFill(start_color="374151", end_color="374151", fill_type="solid")
    
    pass_fill = PatternFill(start_color="D1FAE5", end_color="D1FAE5", fill_type="solid")
    fail_fill = PatternFill(start_color="FEE2E2", end_color="FEE2E2", fill_type="solid")
    skip_fill = PatternFill(start_color="F3F4F6", end_color="F3F4F6", fill_type="solid")
    
    title_font = Font(name="Segoe UI", size=16, bold=True, color="FFFFFF")
    section_font = Font(name="Segoe UI", size=11, bold=True, color="FFFFFF")
    bold_font = Font(name="Segoe UI", size=10, bold=True)
    regular_font = Font(name="Segoe UI", size=10)
    
    pass_font = Font(name="Segoe UI", size=10, bold=True, color="065F46")
    fail_font = Font(name="Segoe UI", size=10, bold=True, color="991B1B")
    skip_font = Font(name="Segoe UI", size=10, bold=True, color="374151")
    
    center_align = Alignment(horizontal="center", vertical="center", wrap_text=True)
    left_align = Alignment(horizontal="left", vertical="center", wrap_text=True)
    
    thin_border = Border(
        left=Side(style='thin', color='E5E7EB'),
        right=Side(style='thin', color='E5E7EB'),
        top=Side(style='thin', color='E5E7EB'),
        bottom=Side(style='thin', color='E5E7EB')
    )
    
    # Title Banner (merged A1:H2 to accommodate framework column)
    ws.merge_cells("A1:H2")
    ws["A1"] = "PlanSphere E2E Automation Testing Report (Selenium & Appium)"
    ws["A1"].font = title_font
    ws["A1"].fill = navy_fill
    ws["A1"].alignment = Alignment(horizontal="left", vertical="center", indent=1)
    
    # Setup Metrics
    total = len(test_results)
    passed = sum(1 for r in test_results if r["status"] == "PASSED")
    failed = sum(1 for r in test_results if r["status"] == "FAILED")
    skipped = sum(1 for r in test_results if r["status"] == "SKIPPED")
    pass_rate = (passed / total * 100) if total > 0 else 0
    total_duration = sum(r["duration"] for r in test_results)
    
    ws["A4"] = "Run Date:"
    ws["B4"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ws["A5"] = "Total Cases:"
    ws["B5"] = total
    ws["C4"] = "Passed:"
    ws["D4"] = passed
    ws["C5"] = "Failed:"
    ws["D5"] = failed
    ws["E4"] = "Skipped:"
    ws["F4"] = skipped
    ws["E5"] = "Pass Rate:"
    ws["F5"] = f"{pass_rate:.1f}%"
    ws["G4"] = "Total Duration:"
    ws["G5"] = f"{total_duration:.2f}s"
    
    for r in range(4, 6):
        for col in ["A", "C", "E", "G"]:
            ws[f"{col}{r}"].font = bold_font
        for col in ["B", "D", "F"]:
            ws[f"{col}{r}"].font = regular_font
            
    # Draw summary border
    for r in range(4, 6):
        for col_idx in range(1, 9):
            cell = ws.cell(row=r, column=col_idx)
            cell.border = thin_border
            
    ws["F5"].font = pass_font if pass_rate == 100 else fail_font
    
    # Table headers
    headers = ["S.No", "Test Case Name", "Automation Driver", "Module", "Description", "Status", "Duration (s)", "Error Details"]
    header_row = 7
    ws.row_dimensions[header_row].height = 28
    
    for idx, header in enumerate(headers, 1):
        cell = ws.cell(row=header_row, column=idx)
        cell.value = header
        cell.font = section_font
        cell.fill = header_fill
        cell.alignment = center_align
        cell.border = thin_border
        
    # Write Test Results
    current_row = 8
    for idx, res in enumerate(test_results, 1):
        ws.row_dimensions[current_row].height = 22
        
        ws.cell(row=current_row, column=1, value=idx).alignment = center_align
        ws.cell(row=current_row, column=2, value=res["name"]).alignment = left_align
        ws.cell(row=current_row, column=3, value=res["framework"]).alignment = center_align
        ws.cell(row=current_row, column=4, value=res["module"]).alignment = center_align
        ws.cell(row=current_row, column=5, value=res["description"]).alignment = left_align
        
        status_cell = ws.cell(row=current_row, column=6, value=res["status"])
        status_cell.alignment = center_align
        if res["status"] == "PASSED":
            status_cell.fill = pass_fill
            status_cell.font = pass_font
        elif res["status"] == "FAILED":
            status_cell.fill = fail_fill
            status_cell.font = fail_font
        else:
            status_cell.fill = skip_fill
            status_cell.font = skip_font
            
        ws.cell(row=current_row, column=7, value=round(res["duration"], 3)).alignment = center_align
        ws.cell(row=current_row, column=8, value=res["error"]).alignment = left_align
        
        # Apply borders & font
        for col_idx in range(1, 9):
            c = ws.cell(row=current_row, column=col_idx)
            c.border = thin_border
            if col_idx != 6:  # Status column keeps its custom font
                c.font = regular_font
                
        current_row += 1
        
    # Autofit Column Widths
    for col in ws.columns:
        max_len = 10
        col_letter = get_column_letter(col[0].column)
        
        for cell in col[6:]:
            if cell.value is not None:
                max_len = max(max_len, len(str(cell.value)))
                
        width = min(max_len + 3, 50)
        if col_letter in ["A", "D", "F"]:
            width = 10
        elif col_letter in ["C", "G"]:
            width = 18
            
        ws.column_dimensions[col_letter].width = width
        
    wb.save(report_path)
    print(f"\nCombined Excel Report Saved successfully: {report_path}")
