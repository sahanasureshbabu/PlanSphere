package com.plansphere.utils;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.reflect.TypeToken;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.*;

public class HTMLReporter {

    public static class BuildHistoryEntry {
        public String buildNumber;
        public String date;
        public int total;
        public int passed;
        public int failed;
        public int skipped;
        public double passRate;
        public String duration;

        public BuildHistoryEntry(String buildNumber, String date, int total, int passed, int failed, int skipped, double passRate, String duration) {
            this.buildNumber = buildNumber;
            this.date = date;
            this.total = total;
            this.passed = passed;
            this.failed = failed;
            this.skipped = skipped;
            this.passRate = passRate;
            this.duration = duration;
        }
    }

    public static void generateReports(List<ExcelReporter.TestResult> results, String buildNumber, String apkVersion, String deviceName, String androidVersion) {
        String baseDir = ConfigReader.getProperty("reports.base.dir", "reports");
        new File(baseDir + "/HTML").mkdirs();
        new File(baseDir + "/Summary").mkdirs();
        new File(baseDir + "/JSON").mkdirs();
        new File(baseDir + "/history").mkdirs();

        String htmlReportPath = ConfigReader.getProperty("html.report.path", "reports/HTML/execution-report.html");
        String dashboardReportPath = ConfigReader.getProperty("html.dashboard.path", "reports/HTML/dashboard.html");
        String trendsReportPath = ConfigReader.getProperty("html.trends.path", "reports/HTML/trends.html");
        String jsonReportPath = ConfigReader.getProperty("json.report.path", "reports/JSON/execution-results.json");
        String mdReportPath = ConfigReader.getProperty("summary.report.path", "reports/Summary/summary.md");

        // Aggregated Metrics
        int total = results.size();
        int passed = 0;
        int failed = 0;
        int skipped = 0;
        long totalDurationMs = 0;

        for (ExcelReporter.TestResult tr : results) {
            totalDurationMs += tr.durationMs;
            if ("PASSED".equalsIgnoreCase(tr.status)) passed++;
            else if ("FAILED".equalsIgnoreCase(tr.status)) failed++;
            else if ("SKIPPED".equalsIgnoreCase(tr.status)) skipped++;
        }
        double passRate = total == 0 ? 0.0 : (passed * 100.0) / total;
        String durationStr = String.format("%.2fs", totalDurationMs / 1000.0);
        String executionDate = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date());

        // 1. Save results to JSON
        saveJSONReport(results, jsonReportPath);

        // 2. Manage History Trend
        List<BuildHistoryEntry> history = updateHistory(baseDir, buildNumber, executionDate, total, passed, failed, skipped, passRate, durationStr);

        // 3. Write Markdown Summary
        writeMarkdownSummary(results, mdReportPath, buildNumber, executionDate, apkVersion, deviceName, androidVersion, total, passed, failed, skipped, passRate, durationStr);

        // 4. Generate HTML Execution Report
        writeExecutionReport(results, htmlReportPath, buildNumber, executionDate, apkVersion, deviceName, androidVersion, total, passed, failed, skipped, passRate, durationStr);

        // 5. Generate HTML Dashboard
        writeDashboardReport(results, dashboardReportPath, buildNumber, executionDate, apkVersion, deviceName, androidVersion, total, passed, failed, skipped, passRate, durationStr);

        // 6. Generate HTML Trends
        writeTrendsReport(history, trendsReportPath, buildNumber, executionDate);
    }

    private static void saveJSONReport(List<ExcelReporter.TestResult> results, String jsonPath) {
        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        try (FileWriter writer = new FileWriter(jsonPath)) {
            gson.toJson(results, writer);
        } catch (IOException e) {
            System.err.println("Failed to write JSON report: " + e.getMessage());
        }
    }

    private static List<BuildHistoryEntry> updateHistory(String baseDir, String buildNumber, String date, int total, int passed, int failed, int skipped, double passRate, String duration) {
        String historyFile = baseDir + "/history/history.json";
        List<BuildHistoryEntry> list = new ArrayList<>();
        Gson gson = new Gson();

        File file = new File(historyFile);
        if (file.exists()) {
            try (FileReader reader = new FileReader(file)) {
                list = gson.fromJson(reader, new TypeToken<List<BuildHistoryEntry>>(){}.getType());
            } catch (Exception e) {
                // ignore
            }
        }
        if (list == null) {
            list = new ArrayList<>();
        }

        // Add current build entry (avoid duplicates for rerun checks)
        list.removeIf(entry -> entry.buildNumber.equals(buildNumber));
        list.add(new BuildHistoryEntry(buildNumber, date.substring(0, 10), total, passed, failed, skipped, passRate, duration));

        // Keep last 15 builds
        if (list.size() > 15) {
            list.remove(0);
        }

        try (FileWriter writer = new FileWriter(historyFile)) {
            gson.toJson(list, writer);
        } catch (IOException e) {
            System.err.println("Failed to update history JSON: " + e.getMessage());
        }

        return list;
    }

    private static void writeMarkdownSummary(List<ExcelReporter.TestResult> results, String path, String buildNumber, String date, String apkVersion,
                                             String device, String androidVersion, int total, int passed, int failed, int skipped, double passRate, String duration) {
        try (FileWriter writer = new FileWriter(path)) {
            writer.write("# Android Appium E2E Execution Summary\n\n");
            writer.write("**Build Number:** " + buildNumber + "\n");
            writer.write("**Execution Date:** " + date + "\n");
            writer.write("**APK Version:** " + apkVersion + "\n");
            writer.write("**Device:** " + device + "\n");
            writer.write("**Android Version:** " + androidVersion + "\n\n");

            writer.write("## Execution Metrics\n\n");
            writer.write("- **Total Test Cases:** " + total + "\n");
            writer.write("- **Passed:** " + passed + "\n");
            writer.write("- **Failed:** " + failed + "\n");
            writer.write("- **Skipped:** " + skipped + "\n");
            writer.write("- **Blocked:** 0\n");
            writer.write("- **Pass Percentage:** " + String.format("%.2f%%", passRate) + "\n");
            writer.write("- **Execution Duration:** " + duration + "\n\n");

            writer.write("## Test Case Execution Details\n\n");
            
            // FAILED TESTS
            writer.write("### FAILED TESTS ✗\n\n");
            boolean hasFailed = false;
            for (ExcelReporter.TestResult tr : results) {
                if ("FAILED".equalsIgnoreCase(tr.status)) {
                    writer.write("✗ **" + tr.id + "** - " + tr.name + "\n");
                    writer.write("  *Reason:* " + tr.failReason + "\n\n");
                    hasFailed = true;
                }
            }
            if (!hasFailed) {
                writer.write("*None*\n\n");
            }

            // SKIPPED TESTS
            writer.write("### SKIPPED TESTS -\n\n");
            boolean hasSkipped = false;
            for (ExcelReporter.TestResult tr : results) {
                if ("SKIPPED".equalsIgnoreCase(tr.status)) {
                    writer.write("- **" + tr.id + "** - " + tr.name + "\n");
                    writer.write("  *Reason:* " + (tr.failReason != null ? tr.failReason : "Feature Disabled") + "\n\n");
                    hasSkipped = true;
                }
            }
            if (!hasSkipped) {
                writer.write("*None*\n\n");
            }

            // PASSED TESTS (sample list to keep summary clean)
            writer.write("### PASSED TESTS (Sample) ✓\n\n");
            int passedCount = 0;
            for (ExcelReporter.TestResult tr : results) {
                if ("PASSED".equalsIgnoreCase(tr.status)) {
                    writer.write("✓ **" + tr.id + "** - " + tr.name + "\n");
                    passedCount++;
                    if (passedCount >= 10) {
                        writer.write("\n*... and " + (passed - 10) + " more passed test cases.*\n");
                        break;
                    }
                }
            }
        } catch (IOException e) {
            System.err.println("Failed to write Markdown Summary: " + e.getMessage());
        }
    }

    private static void writeExecutionReport(List<ExcelReporter.TestResult> results, String path, String buildNumber, String date, String apkVersion,
                                             String device, String androidVersion, int total, int passed, int failed, int skipped, double passRate, String duration) {
        StringBuilder html = new StringBuilder();
        html.append("<!DOCTYPE html>\n<html>\n<head>\n");
        html.append("<title>PlanSphere E2E Automation Report</title>\n");
        html.append("<meta charset='UTF-8'>\n");
        html.append("<meta name='viewport' content='width=device-width, initial-scale=1.0'>\n");
        html.append("<link href='https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap' rel='stylesheet'>\n");
        
        // Custom CSS - Glassmorphism, Dark style
        html.append("<style>\n");
        html.append("  :root { --bg: #0f172a; --panel-bg: rgba(30, 41, 59, 0.7); --border: rgba(255, 255, 255, 0.08); --text: #e2e8f0; --primary: #3b82f6; --success: #10b981; --fail: #ef4444; --skip: #f59e0b; }\n");
        html.append("  * { box-sizing: border-box; margin: 0; padding: 0; }\n");
        html.append("  body { font-family: 'Inter', sans-serif; background-color: var(--bg); color: var(--text); padding: 2rem; min-height: 100vh; line-height: 1.5; }\n");
        html.append("  header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; border-bottom: 1px solid var(--border); padding-bottom: 1rem; }\n");
        html.append("  h1 { font-size: 1.8rem; font-weight: 700; color: #fff; text-shadow: 0 4px 10px rgba(59, 130, 246, 0.2); }\n");
        html.append("  .nav-links { display: flex; gap: 1rem; }\n");
        html.append("  .nav-links a { color: var(--text); text-decoration: none; padding: 0.5rem 1rem; border-radius: 6px; background: rgba(255,255,255,0.05); border: 1px solid var(--border); transition: 0.2s; }\n");
        html.append("  .nav-links a.active, .nav-links a:hover { background: var(--primary); color: white; border-color: var(--primary); }\n");
        html.append("  .grid-kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 1.2rem; margin-bottom: 2rem; }\n");
        html.append("  .kpi-card { background: var(--panel-bg); backdrop-filter: blur(10px); border: 1px solid var(--border); border-radius: 12px; padding: 1.5rem; text-align: center; box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3); }\n");
        html.append("  .kpi-title { font-size: 0.85rem; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.5rem; }\n");
        html.append("  .kpi-value { font-size: 2rem; font-weight: 700; }\n");
        html.append("  .kpi-total { color: #fff; }\n");
        html.append("  .kpi-pass { color: var(--success); }\n");
        html.append("  .kpi-fail { color: var(--fail); }\n");
        html.append("  .kpi-skip { color: var(--skip); }\n");
        html.append("  .meta-panel { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1.5rem; background: var(--panel-bg); border: 1px solid var(--border); border-radius: 12px; padding: 1.5rem; margin-bottom: 2rem; font-size: 0.9rem; }\n");
        html.append("  .meta-item { display: flex; justify-content: space-between; border-bottom: 1px solid rgba(255,255,255,0.04); padding: 0.5rem 0; }\n");
        html.append("  .meta-item span:first-child { color: #94a3b8; }\n");
        html.append("  .meta-item span:last-child { font-weight: 600; color: #fff; }\n");
        html.append("  .filters { display: flex; flex-wrap: wrap; gap: 1rem; margin-bottom: 1.5rem; align-items: center; }\n");
        html.append("  .search-input { background: rgba(15, 23, 42, 0.6); border: 1px solid var(--border); border-radius: 6px; padding: 0.6rem 1rem; color: #fff; width: 300px; font-family: inherit; }\n");
        html.append("  .filter-btn { background: rgba(255,255,255,0.04); border: 1px solid var(--border); border-radius: 6px; padding: 0.6rem 1.2rem; color: var(--text); cursor: pointer; transition: 0.2s; font-family: inherit; }\n");
        html.append("  .filter-btn:hover, .filter-btn.active { background: rgba(59, 130, 246, 0.15); border-color: var(--primary); color: #fff; }\n");
        html.append("  .table-container { background: var(--panel-bg); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }\n");
        html.append("  table { width: 100%; border-collapse: collapse; text-align: left; font-size: 0.95rem; }\n");
        html.append("  th, td { padding: 1rem 1.5rem; border-bottom: 1px solid rgba(255,255,255,0.05); }\n");
        html.append("  th { background: rgba(0, 0, 0, 0.2); font-weight: 600; color: #fff; text-transform: uppercase; font-size: 0.75rem; letter-spacing: 0.05em; }\n");
        html.append("  tr:hover { background: rgba(255,255,255,0.02); }\n");
        html.append("  .badge { display: inline-block; padding: 0.25rem 0.6rem; border-radius: 50px; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; }\n");
        html.append("  .badge-passed { background: rgba(16, 185, 129, 0.15); color: var(--success); }\n");
        html.append("  .badge-failed { background: rgba(239, 68, 68, 0.15); color: var(--fail); }\n");
        html.append("  .badge-skipped { background: rgba(245, 158, 11, 0.15); color: var(--skip); }\n");
        html.append("  .accordion-content { display: none; background: rgba(0, 0, 0, 0.15); padding: 1.5rem; border-bottom: 1px solid rgba(255,255,255,0.05); }\n");
        html.append("  .accordion-grid { display: grid; grid-template-columns: 2fr 1fr; gap: 1.5rem; }\n");
        html.append("  .steps-box { background: rgba(15,23,42,0.4); border: 1px solid var(--border); padding: 1rem; border-radius: 8px; font-family: monospace; white-space: pre-line; line-height: 1.6; }\n");
        html.append("  .screenshot-box img { max-width: 100%; border-radius: 8px; border: 1px solid var(--border); box-shadow: 0 4px 12px rgba(0,0,0,0.5); cursor: pointer; transition: 0.2s; }\n");
        html.append("  .screenshot-box img:hover { transform: scale(1.02); }\n");
        html.append("  .log-link { display: inline-block; margin-top: 0.5rem; color: var(--primary); text-decoration: none; font-size: 0.85rem; }\n");
        html.append("  .log-link:hover { text-decoration: underline; }\n");
        html.append("</style>\n");
        
        // JS Logic
        html.append("<script>\n");
        html.append("  function toggleRow(id) {\n");
        html.append("    var el = document.getElementById('details-' + id);\n");
        html.append("    if (el.style.display === 'block') el.style.display = 'none';\n");
        html.append("    else el.style.display = 'block';\n");
        html.append("  }\n");
        html.append("  function filterStatus(status) {\n");
        html.append("    document.querySelectorAll('.filter-btn').forEach(btn => btn.classList.remove('active'));\n");
        html.append("    event.target.classList.add('active');\n");
        html.append("    document.querySelectorAll('.test-row').forEach(row => {\n");
        html.append("      var rowStatus = row.getAttribute('data-status');\n");
        html.append("      var detailsRow = document.getElementById('details-' + row.id);\n");
        html.append("      if (status === 'ALL' || rowStatus === status) {\n");
        html.append("        row.style.display = '';\n");
        html.append("      } else {\n");
        html.append("        row.style.display = 'none';\n");
        html.append("        if (detailsRow) detailsRow.style.display = 'none';\n");
        html.append("      }\n");
        html.append("    });\n");
        html.append("  }\n");
        html.append("  function searchTests() {\n");
        html.append("    var query = document.getElementById('search').value.toLowerCase();\n");
        html.append("    document.querySelectorAll('.test-row').forEach(row => {\n");
        html.append("      var text = row.innerText.toLowerCase();\n");
        html.append("      if (text.indexOf(query) > -1) {\n");
        html.append("        row.style.display = '';\n");
        html.append("      } else {\n");
        html.append("        row.style.display = 'none';\n");
        html.append("        var detailsRow = document.getElementById('details-' + row.id);\n");
        html.append("        if (detailsRow) detailsRow.style.display = 'none';\n");
        html.append("      }\n");
        html.append("    });\n");
        html.append("  }\n");
        html.append("</script>\n");
        html.append("</head>\n<body>\n");

        // Header
        html.append("<header>\n");
        html.append("  <h1>PlanSphere E2E Test Suite Execution</h1>\n");
        html.append("  <div class='nav-links'>\n");
        html.append("    <a href='execution-report.html' class='active'>Detailed Report</a>\n");
        html.append("    <a href='dashboard.html'>Dashboard</a>\n");
        html.append("    <a href='trends.html'>Historic Trends</a>\n");
        html.append("  </div>\n");
        html.append("</header>\n");

        // KPIs
        html.append("<div class='grid-kpis'>\n");
        html.append("  <div class='kpi-card'><div class='kpi-title'>Total Tests</div><div class='kpi-value kpi-total'>" + total + "</div></div>\n");
        html.append("  <div class='kpi-card'><div class='kpi-title'>Passed</div><div class='kpi-value kpi-pass'>" + passed + "</div></div>\n");
        html.append("  <div class='kpi-card'><div class='kpi-title'>Failed</div><div class='kpi-value kpi-fail'>" + failed + "</div></div>\n");
        html.append("  <div class='kpi-card'><div class='kpi-title'>Skipped</div><div class='kpi-value kpi-skip'>" + skipped + "</div></div>\n");
        html.append("  <div class='kpi-card'><div class='kpi-title'>Pass Rate</div><div class='kpi-value kpi-pass'>" + String.format("%.1f%%", passRate) + "</div></div>\n");
        html.append("</div>\n");

        // Meta Info Panel
        html.append("<div class='meta-panel'>\n");
        html.append("  <div>\n");
        html.append("    <div class='meta-item'><span>Build Number</span><span>" + buildNumber + "</span></div>\n");
        html.append("    <div class='meta-item'><span>APK Version</span><span>" + apkVersion + "</span></div>\n");
        html.append("  </div>\n");
        html.append("  <div>\n");
        html.append("    <div class='meta-item'><span>Device</span><span>" + device + "</span></div>\n");
        html.append("    <div class='meta-item'><span>Android AVD Version</span><span>" + androidVersion + "</span></div>\n");
        html.append("  </div>\n");
        html.append("  <div>\n");
        html.append("    <div class='meta-item'><span>Execution Timestamp</span><span>" + date + "</span></div>\n");
        html.append("    <div class='meta-item'><span>Execution Duration</span><span>" + duration + "</span></div>\n");
        html.append("  </div>\n");
        html.append("</div>\n");

        // Filters
        html.append("<div class='filters'>\n");
        html.append("  <input type='text' id='search' class='search-input' oninput='searchTests()' placeholder='Search by Test ID, name, module...'>\n");
        html.append("  <button class='filter-btn active' onclick='filterStatus(\"ALL\")'>All (" + total + ")</button>\n");
        html.append("  <button class='filter-btn' onclick='filterStatus(\"PASSED\")'>Passed (" + passed + ")</button>\n");
        html.append("  <button class='filter-btn' onclick='filterStatus(\"FAILED\")'>Failed (" + failed + ")</button>\n");
        html.append("  <button class='filter-btn' onclick='filterStatus(\"SKIPPED\")'>Skipped (" + skipped + ")</button>\n");
        html.append("</div>\n");

        // Results Table
        html.append("<div class='table-container'>\n");
        html.append("  <table>\n");
        html.append("    <thead>\n");
        html.append("      <tr>\n");
        html.append("        <th>Test ID</th>\n");
        html.append("        <th>Module</th>\n");
        html.append("        <th>Test Scenario Name</th>\n");
        html.append("        <th>Priority</th>\n");
        html.append("        <th>Status</th>\n");
        html.append("        <th>Time</th>\n");
        html.append("      </tr>\n");
        html.append("    </thead>\n");
        html.append("    <tbody>\n");

        for (ExcelReporter.TestResult tr : results) {
            String badgeClass = "badge-passed";
            if ("FAILED".equalsIgnoreCase(tr.status)) badgeClass = "badge-failed";
            else if ("SKIPPED".equalsIgnoreCase(tr.status)) badgeClass = "badge-skipped";

            html.append("      <tr id='" + tr.id + "' class='test-row' data-status='" + tr.status + "' onclick='toggleRow(\"" + tr.id + "\")' style='cursor:pointer;'>\n");
            html.append("        <td style='font-weight:600; color:#fff;'>" + tr.id + "</td>\n");
            html.append("        <td>" + tr.module + "</td>\n");
            html.append("        <td>" + tr.name + "</td>\n");
            html.append("        <td>" + tr.priority + "</td>\n");
            html.append("        <td><span class='badge " + badgeClass + "'>" + tr.status + "</span></td>\n");
            html.append("        <td>" + String.format("%.2fs", tr.durationMs / 1000.0) + "</td>\n");
            html.append("      </tr>\n");

            // Accordion detail block
            html.append("      <tr id='details-" + tr.id + "' class='accordion-content' style='display:none;'><td colspan='6'>\n");
            html.append("        <div class='accordion-grid'>\n");
            html.append("          <div>\n");
            html.append("            <h4 style='color:#fff; margin-bottom:0.5rem;'>Execution Steps & Verifications</h4>\n");
            html.append("            <div class='steps-box'>" + tr.steps + "</div>\n");
            
            if ("FAILED".equalsIgnoreCase(tr.status)) {
                html.append("            <h4 style='color:var(--fail); margin-top:1rem; margin-bottom:0.5rem;'>Exception / Fail Reason</h4>\n");
                html.append("            <div class='steps-box' style='background:rgba(239,68,68,0.08); border-color:rgba(239,68,68,0.2); color:#fca5a5;'>" + tr.failReason + "\n\n" + tr.stackTrace + "</div>\n");
            }
            if (tr.logPath != null) {
                html.append("            <a href='../" + tr.logPath + "' target='_blank' class='log-link'>View Execution logs & Logcat output</a>\n");
            }
            html.append("          </div>\n");
            html.append("          <div class='screenshot-box'>\n");
            if (tr.screenshotPath != null) {
                html.append("            <h4 style='color:#fff; margin-bottom:0.5rem;'>Device Screenshot</h4>\n");
                html.append("            <a href='../" + tr.screenshotPath + "' target='_blank'><img src='../" + tr.screenshotPath + "' alt='Screenshot failure'></a>\n");
            } else {
                html.append("            <div style='background:rgba(255,255,255,0.02); height:120px; border-radius:8px; border:1px dashed var(--border); display:flex; align-items:center; justify-content:center; color:#64748b;'>No Screenshot captured</div>\n");
            }
            html.append("          </div>\n");
            html.append("        </div>\n");
            html.append("      </td></tr>\n");
        }

        html.append("    </tbody>\n");
        html.append("  </table>\n");
        html.append("</div>\n");
        html.append("</body>\n</html>\n");

        try (FileWriter writer = new FileWriter(path)) {
            writer.write(html.toString());
        } catch (IOException e) {
            System.err.println("Failed to write HTML Execution report: " + e.getMessage());
        }
    }

    private static void writeDashboardReport(List<ExcelReporter.TestResult> results, String path, String buildNumber, String date, String apkVersion,
                                             String device, String androidVersion, int total, int passed, int failed, int skipped, double passRate, String duration) {
        StringBuilder html = new StringBuilder();
        html.append("<!DOCTYPE html>\n<html>\n<head>\n");
        html.append("<title>PlanSphere E2E Automation Dashboard</title>\n");
        html.append("<meta charset='UTF-8'>\n");
        html.append("<link href='https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap' rel='stylesheet'>\n");
        html.append("<style>\n");
        html.append("  :root { --bg: #0f172a; --panel-bg: rgba(30, 41, 59, 0.7); --border: rgba(255, 255, 255, 0.08); --text: #e2e8f0; --primary: #3b82f6; --success: #10b981; --fail: #ef4444; --skip: #f59e0b; }\n");
        html.append("  body { font-family: 'Inter', sans-serif; background-color: var(--bg); color: var(--text); padding: 2rem; }\n");
        html.append("  header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; border-bottom: 1px solid var(--border); padding-bottom: 1rem; }\n");
        html.append("  h1 { font-size: 1.8rem; color: #fff; }\n");
        html.append("  .nav-links { display: flex; gap: 1rem; }\n");
        html.append("  .nav-links a { color: var(--text); text-decoration: none; padding: 0.5rem 1rem; border-radius: 6px; background: rgba(255,255,255,0.05); border: 1px solid var(--border); }\n");
        html.append("  .nav-links a.active, .nav-links a:hover { background: var(--primary); color: white; border-color: var(--primary); }\n");
        
        html.append("  .dashboard-grid { display: grid; grid-template-columns: 1fr 2fr; gap: 2rem; }\n");
        html.append("  .card { background: var(--panel-bg); border: 1px solid var(--border); border-radius: 12px; padding: 2rem; box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3); }\n");
        html.append("  .card-title { font-size: 1.1rem; font-weight: 600; color: #fff; margin-bottom: 1.5rem; border-left: 4px solid var(--primary); padding-left: 0.5rem; }\n");
        
        // Circular progress SVG chart
        html.append("  .chart-circle { position: relative; width: 200px; height: 200px; margin: 0 auto; }\n");
        html.append("  .chart-circle svg { transform: rotate(-90deg); }\n");
        html.append("  .chart-text { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; }\n");
        html.append("  .chart-percentage { font-size: 2.2rem; font-weight: 700; color: var(--success); }\n");
        html.append("  .chart-label { font-size: 0.8rem; color: #94a3b8; }\n");
        
        // Module Bars
        html.append("  .module-list { display: flex; flex-direction: column; gap: 1rem; }\n");
        html.append("  .module-bar-container { display: flex; align-items: center; justify-content: space-between; gap: 1rem; }\n");
        html.append("  .module-name { font-size: 0.9rem; min-width: 150px; color: #cbd5e1; }\n");
        html.append("  .bar-wrapper { flex-grow: 1; background: rgba(255,255,255,0.05); height: 12px; border-radius: 50px; overflow: hidden; display: flex; }\n");
        html.append("  .bar-segment { height: 100%; }\n");
        html.append("  .bar-passed { background: var(--success); }\n");
        html.append("  .bar-failed { background: var(--fail); }\n");
        html.append("  .bar-skipped { background: var(--skip); }\n");
        html.append("  .module-metrics { font-size: 0.85rem; font-weight: 600; color: #94a3b8; min-width: 70px; text-align: right; }\n");
        html.append("</style>\n");
        html.append("</head>\n<body>\n");

        html.append("<header>\n");
        html.append("  <h1>PlanSphere E2E Quality Metrics</h1>\n");
        html.append("  <div class='nav-links'>\n");
        html.append("    <a href='execution-report.html'>Detailed Report</a>\n");
        html.append("    <a href='dashboard.html' class='active'>Dashboard</a>\n");
        html.append("    <a href='trends.html'>Historic Trends</a>\n");
        html.append("  </div>\n");
        html.append("</header>\n");

        // SVG details
        double strokeDash = 2 * Math.PI * 80; // circumference for r=80
        double dashoffset = strokeDash * (1 - (passRate / 100.0));

        html.append("<div class='dashboard-grid'>\n");
        
        // Left Card - Success Circle
        html.append("  <div class='card'>\n");
        html.append("    <div class='card-title'>Pass Rate Summary</div>\n");
        html.append("    <div class='chart-circle'>\n");
        html.append("      <svg width='200' height='200'>\n");
        html.append("        <circle cx='100' cy='100' r='80' fill='transparent' stroke='rgba(255,255,255,0.05)' stroke-width='16'/>\n");
        html.append("        <circle cx='100' cy='100' r='80' fill='transparent' stroke='var(--success)' stroke-width='16' stroke-dasharray='" + strokeDash + "' stroke-dashoffset='" + dashoffset + "' stroke-linecap='round'/>\n");
        html.append("      </svg>\n");
        html.append("      <div class='chart-text'>\n");
        html.append("        <div class='chart-percentage'>" + String.format("%.1f%%", passRate) + "</div>\n");
        html.append("        <div class='chart-label'>Pass Rate</div>\n");
        html.append("      </div>\n");
        html.append("    </div>\n");
        html.append("    <div style='margin-top: 2rem; font-size:0.9rem; color:#94a3b8;'>\n");
        html.append("      <div style='display:flex; justify-content:space-between; margin-bottom:0.5rem;'><span>Passed</span><span style='color:var(--success); font-weight:600;'>" + passed + "</span></div>\n");
        html.append("      <div style='display:flex; justify-content:space-between; margin-bottom:0.5rem;'><span>Failed</span><span style='color:var(--fail); font-weight:600;'>" + failed + "</span></div>\n");
        html.append("      <div style='display:flex; justify-content:space-between;'><span>Skipped</span><span style='color:var(--skip); font-weight:600;'>" + skipped + "</span></div>\n");
        html.append("    </div>\n");
        html.append("  </div>\n");

        // Right Card - Module Bars
        html.append("  <div class='card'>\n");
        html.append("    <div class='card-title'>Module Breakdown</div>\n");
        html.append("    <div class='module-list'>\n");

        // Group by module
        Map<String, int[]> map = new LinkedHashMap<>(); // module -> [total, passed, failed, skipped]
        for (ExcelReporter.TestResult tr : results) {
            map.putIfAbsent(tr.module, new int[4]);
            int[] counts = map.get(tr.module);
            counts[0]++;
            if ("PASSED".equalsIgnoreCase(tr.status)) counts[1]++;
            else if ("FAILED".equalsIgnoreCase(tr.status)) counts[2]++;
            else if ("SKIPPED".equalsIgnoreCase(tr.status)) counts[3]++;
        }

        for (Map.Entry<String, int[]> entry : map.entrySet()) {
            String modName = entry.getKey();
            int[] counts = entry.getValue();
            double pWidth = (counts[1] * 100.0) / counts[0];
            double fWidth = (counts[2] * 100.0) / counts[0];
            double sWidth = (counts[3] * 100.0) / counts[0];

            html.append("      <div class='module-bar-container'>\n");
            html.append("        <div class='module-name'>" + modName + "</div>\n");
            html.append("        <div class='bar-wrapper'>\n");
            if (counts[1] > 0) html.append("          <div class='bar-segment bar-passed' style='width: " + pWidth + "%;'></div>\n");
            if (counts[2] > 0) html.append("          <div class='bar-segment bar-failed' style='width: " + fWidth + "%;'></div>\n");
            if (counts[3] > 0) html.append("          <div class='bar-segment bar-skipped' style='width: " + sWidth + "%;'></div>\n");
            html.append("        </div>\n");
            html.append("        <div class='module-metrics'>" + counts[1] + "/" + counts[0] + "</div>\n");
            html.append("      </div>\n");
        }

        html.append("    </div>\n");
        html.append("  </div>\n");
        html.append("</div>\n");
        html.append("</body>\n</html>\n");

        try (FileWriter writer = new FileWriter(path)) {
            writer.write(html.toString());
        } catch (IOException e) {
            System.err.println("Failed to write HTML Dashboard report: " + e.getMessage());
        }
    }

    private static void writeTrendsReport(List<BuildHistoryEntry> history, String path, String buildNumber, String date) {
        StringBuilder html = new StringBuilder();
        html.append("<!DOCTYPE html>\n<html>\n<head>\n");
        html.append("<title>PlanSphere E2E Trend Analysis</title>\n");
        html.append("<meta charset='UTF-8'>\n");
        html.append("<link href='https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap' rel='stylesheet'>\n");
        html.append("<style>\n");
        html.append("  :root { --bg: #0f172a; --panel-bg: rgba(30, 41, 59, 0.7); --border: rgba(255, 255, 255, 0.08); --text: #e2e8f0; --primary: #3b82f6; --success: #10b981; --fail: #ef4444; --skip: #f59e0b; }\n");
        html.append("  body { font-family: 'Inter', sans-serif; background-color: var(--bg); color: var(--text); padding: 2rem; }\n");
        html.append("  header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; border-bottom: 1px solid var(--border); padding-bottom: 1rem; }\n");
        html.append("  h1 { font-size: 1.8rem; color: #fff; }\n");
        html.append("  .nav-links { display: flex; gap: 1rem; }\n");
        html.append("  .nav-links a { color: var(--text); text-decoration: none; padding: 0.5rem 1rem; border-radius: 6px; background: rgba(255,255,255,0.05); border: 1px solid var(--border); }\n");
        html.append("  .nav-links a.active, .nav-links a:hover { background: var(--primary); color: white; border-color: var(--primary); }\n");
        html.append("  .card { background: var(--panel-bg); border: 1px solid var(--border); border-radius: 12px; padding: 2rem; box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3); margin-bottom: 2rem; }\n");
        html.append("  .card-title { font-size: 1.1rem; font-weight: 600; color: #fff; margin-bottom: 1.5rem; border-left: 4px solid var(--primary); padding-left: 0.5rem; }\n");
        
        // Graphical Grid for historical items
        html.append("  .graph-wrapper { display: flex; align-items: flex-end; gap: 1.5rem; height: 300px; padding-top: 2rem; border-bottom: 2px solid var(--border); border-left: 2px solid var(--border); position: relative; margin: 2rem; }\n");
        html.append("  .graph-bar-container { display: flex; flex-direction: column; align-items: center; flex-grow: 1; height: 100%; justify-content: flex-end; }\n");
        html.append("  .stacked-bar { width: 40px; display: flex; flex-direction: column; border-radius: 4px 4px 0 0; overflow: hidden; }\n");
        html.append("  .stacked-segment { width: 100%; transition: height 0.5s; }\n");
        html.append("  .stacked-pass { background: var(--success); }\n");
        html.append("  .stacked-fail { background: var(--fail); }\n");
        html.append("  .stacked-skip { background: var(--skip); }\n");
        html.append("  .bar-label { font-size: 0.75rem; margin-top: 0.5rem; color: #94a3b8; text-align: center; }\n");
        html.append("  .rate-label { font-size: 0.75rem; font-weight: 600; color: #fff; margin-bottom: 0.25rem; }\n");
        html.append("  .grid-lines { position: absolute; width: 100%; left: 0; display: flex; flex-direction: column; justify-content: space-between; height: 100%; pointer-events: none; }\n");
        html.append("  .grid-line { border-top: 1px dashed rgba(255,255,255,0.03); width: 100%; position: relative; }\n");
        html.append("  .grid-line span { position: absolute; left: -35px; top: -8px; font-size: 0.7rem; color: #64748b; }\n");
        html.append("</style>\n");
        html.append("</head>\n<body>\n");

        html.append("<header>\n");
        html.append("  <h1>PlanSphere Historic Quality Trends</h1>\n");
        html.append("  <div class='nav-links'>\n");
        html.append("    <a href='execution-report.html'>Detailed Report</a>\n");
        html.append("    <a href='dashboard.html'>Dashboard</a>\n");
        html.append("    <a href='trends.html' class='active'>Historic Trends</a>\n");
        html.append("  </div>\n");
        html.append("</header>\n");

        html.append("<div class='card'>\n");
        html.append("  <div class='card-title'>Build Quality & Test Distribution Trends</div>\n");
        html.append("  <div class='graph-wrapper'>\n");
        
        // grid markings
        html.append("    <div class='grid-lines'>\n");
        html.append("      <div class='grid-line'><span>100%</span></div>\n");
        html.append("      <div class='grid-line'><span>75%</span></div>\n");
        html.append("      <div class='grid-line'><span>50%</span></div>\n");
        html.append("      <div class='grid-line'><span>25%</span></div>\n");
        html.append("      <div class='grid-line' style='border-top:none;'><span>0%</span></div>\n");
        html.append("    </div>\n");

        for (BuildHistoryEntry entry : history) {
            double pPct = entry.total == 0 ? 0.0 : (entry.passed * 100.0) / entry.total;
            double fPct = entry.total == 0 ? 0.0 : (entry.failed * 100.0) / entry.total;
            double sPct = entry.total == 0 ? 0.0 : (entry.skipped * 100.0) / entry.total;
            
            // Bar heights proportional
            double heightPass = pPct * 2.5; // max height is 250px
            double heightFail = fPct * 2.5;
            double heightSkip = sPct * 2.5;

            html.append("    <div class='graph-bar-container'>\n");
            html.append("      <span class='rate-label'>" + String.format("%.0f%%", entry.passRate) + "</span>\n");
            html.append("      <div class='stacked-bar'>\n");
            if (entry.skipped > 0) html.append("        <div class='stacked-segment stacked-skip' style='height: " + heightSkip + "px;'></div>\n");
            if (entry.failed > 0) html.append("        <div class='stacked-segment stacked-fail' style='height: " + heightFail + "px;'></div>\n");
            if (entry.passed > 0) html.append("        <div class='stacked-segment stacked-pass' style='height: " + heightPass + "px;'></div>\n");
            html.append("      </div>\n");
            html.append("      <span class='bar-label'>" + entry.buildNumber + "<br><span style='font-size:0.6rem; color:#64748b;'>" + entry.date + "</span></span>\n");
            html.append("    </div>\n");
        }

        html.append("  </div>\n");
        html.append("</div>\n");
        html.append("</body>\n</html>\n");

        try (FileWriter writer = new FileWriter(path)) {
            writer.write(html.toString());
        } catch (IOException e) {
            System.err.println("Failed to write HTML Trends report: " + e.getMessage());
        }
    }
}
