package com.plansphere.utils;

import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.*;

public class ExcelReporter {

    public static class TestResult {
        public String id;
        public String module;
        public String name;
        public String priority;
        public String status; // PASSED, FAILED, SKIPPED
        public long durationMs;
        public String failReason;
        public String stackTrace;
        public String screenshotPath;
        public String logPath;
        public String steps;
        public String testData;
        public String expectedResult;

        public TestResult(String id, String module, String name, String priority, String status, long durationMs,
                          String failReason, String stackTrace, String screenshotPath, String logPath,
                          String steps, String testData, String expectedResult) {
            this.id = id;
            this.module = module;
            this.name = name;
            this.priority = priority;
            this.status = status;
            this.durationMs = durationMs;
            this.failReason = failReason;
            this.stackTrace = stackTrace;
            this.screenshotPath = screenshotPath;
            this.logPath = logPath;
            this.steps = steps;
            this.testData = testData;
            this.expectedResult = expectedResult;
        }
    }

    public static void generateReports(List<TestResult> results) {
        String baseDir = ConfigReader.getProperty("reports.base.dir", "reports");
        new File(baseDir + "/Excel").mkdirs();

        String mainReportPath = ConfigReader.getProperty("excel.report.path", "reports/Excel/Automation_Test_Report.xlsx");
        String passedReportPath = ConfigReader.getProperty("excel.passed.path", "reports/Excel/Passed_Test_Cases.xlsx");
        String failedReportPath = ConfigReader.getProperty("excel.failed.path", "reports/Excel/Failed_Test_Cases.xlsx");
        String summaryReportPath = ConfigReader.getProperty("excel.summary.path", "reports/Excel/Execution_Summary.xlsx");

        // 1. Generate Main Report (contains all 7 sheets)
        try (Workbook mainWorkbook = new XSSFWorkbook()) {
            createExecutedSheet(mainWorkbook, results);
            createPassedSheet(mainWorkbook, results);
            createFailedSheet(mainWorkbook, results);
            createSkippedSheet(mainWorkbook, results);
            createMetricsSheet(mainWorkbook, results);
            createDefectSheet(mainWorkbook, results);
            createPassRateSummarySheet(mainWorkbook, results);

            try (FileOutputStream fos = new FileOutputStream(mainReportPath)) {
                mainWorkbook.write(fos);
            }
            System.out.println("Excel Main Report generated: " + new File(mainReportPath).getAbsolutePath());
        } catch (IOException e) {
            System.err.println("Failed to generate main Excel report: " + e.getMessage());
        }

        // 2. Generate Passed Tests Report
        try (Workbook passedWorkbook = new XSSFWorkbook()) {
            createPassedSheet(passedWorkbook, results);
            try (FileOutputStream fos = new FileOutputStream(passedReportPath)) {
                passedWorkbook.write(fos);
            }
            System.out.println("Excel Passed Report generated: " + new File(passedReportPath).getAbsolutePath());
        } catch (IOException e) {
            System.err.println("Failed to generate passed Excel report: " + e.getMessage());
        }

        // 3. Generate Failed Tests Report
        try (Workbook failedWorkbook = new XSSFWorkbook()) {
            createFailedSheet(failedWorkbook, results);
            createDefectSheet(failedWorkbook, results);
            try (FileOutputStream fos = new FileOutputStream(failedReportPath)) {
                failedWorkbook.write(fos);
            }
            System.out.println("Excel Failed Report generated: " + new File(failedReportPath).getAbsolutePath());
        } catch (IOException e) {
            System.err.println("Failed to generate failed Excel report: " + e.getMessage());
        }

        // 4. Generate Execution Summary Report
        try (Workbook summaryWorkbook = new XSSFWorkbook()) {
            createMetricsSheet(summaryWorkbook, results);
            try (FileOutputStream fos = new FileOutputStream(summaryReportPath)) {
                summaryWorkbook.write(fos);
            }
            System.out.println("Excel Summary Report generated: " + new File(summaryReportPath).getAbsolutePath());
        } catch (IOException e) {
            System.err.println("Failed to generate summary Excel report: " + e.getMessage());
        }
    }

    private static void createExecutedSheet(Workbook wb, List<TestResult> results) {
        Sheet sheet = wb.createSheet("Executed Test Cases");
        sheet.setDisplayGridlines(true);

        Row headerRow = sheet.createRow(0);
        String[] headers = {"Test ID", "Module", "Test Name", "Priority", "Status", "Execution Time (s)"};
        
        CellStyle headerStyle = getHeaderStyle(wb);
        for (int i = 0; i < headers.length; i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(headerStyle);
        }

        int rowNum = 1;
        for (TestResult tr : results) {
            Row row = sheet.createRow(rowNum++);
            row.createCell(0).setCellValue(tr.id);
            row.createCell(1).setCellValue(tr.module);
            row.createCell(2).setCellValue(tr.name);
            row.createCell(3).setCellValue(tr.priority);
            
            Cell statusCell = row.createCell(4);
            statusCell.setCellValue(tr.status);
            statusCell.setCellStyle(getStatusStyle(wb, tr.status));

            row.createCell(5).setCellValue(tr.durationMs / 1000.0);
        }

        autoSizeColumns(sheet, headers.length);
    }

    private static void createPassedSheet(Workbook wb, List<TestResult> results) {
        Sheet sheet = wb.createSheet("Passed Tests");
        sheet.setDisplayGridlines(true);

        Row headerRow = sheet.createRow(0);
        String[] headers = {"Test ID", "Module", "Test Name", "Priority", "Execution Time (s)"};
        
        CellStyle headerStyle = getHeaderStyle(wb);
        for (int i = 0; i < headers.length; i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(headerStyle);
        }

        int rowNum = 1;
        for (TestResult tr : results) {
            if ("PASSED".equalsIgnoreCase(tr.status)) {
                Row row = sheet.createRow(rowNum++);
                row.createCell(0).setCellValue(tr.id);
                row.createCell(1).setCellValue(tr.module);
                row.createCell(2).setCellValue(tr.name);
                row.createCell(3).setCellValue(tr.priority);
                row.createCell(4).setCellValue(tr.durationMs / 1000.0);
            }
        }

        autoSizeColumns(sheet, headers.length);
    }

    private static void createFailedSheet(Workbook wb, List<TestResult> results) {
        Sheet sheet = wb.createSheet("Failed Tests");
        sheet.setDisplayGridlines(true);

        Row headerRow = sheet.createRow(0);
        String[] headers = {"Test ID", "Module", "Test Name", "Priority", "Failure Reason", "Screenshot Path"};
        
        CellStyle headerStyle = getHeaderStyle(wb);
        for (int i = 0; i < headers.length; i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(headerStyle);
        }

        int rowNum = 1;
        for (TestResult tr : results) {
            if ("FAILED".equalsIgnoreCase(tr.status)) {
                Row row = sheet.createRow(rowNum++);
                row.createCell(0).setCellValue(tr.id);
                row.createCell(1).setCellValue(tr.module);
                row.createCell(2).setCellValue(tr.name);
                row.createCell(3).setCellValue(tr.priority);
                row.createCell(4).setCellValue(tr.failReason);
                row.createCell(5).setCellValue(tr.screenshotPath == null ? "N/A" : tr.screenshotPath);
            }
        }

        autoSizeColumns(sheet, headers.length);
    }

    private static void createSkippedSheet(Workbook wb, List<TestResult> results) {
        Sheet sheet = wb.createSheet("Skipped Tests");
        sheet.setDisplayGridlines(true);

        Row headerRow = sheet.createRow(0);
        String[] headers = {"Test ID", "Module", "Test Name", "Priority", "Skip Reason"};
        
        CellStyle headerStyle = getHeaderStyle(wb);
        for (int i = 0; i < headers.length; i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(headerStyle);
        }

        int rowNum = 1;
        for (TestResult tr : results) {
            if ("SKIPPED".equalsIgnoreCase(tr.status)) {
                Row row = sheet.createRow(rowNum++);
                row.createCell(0).setCellValue(tr.id);
                row.createCell(1).setCellValue(tr.module);
                row.createCell(2).setCellValue(tr.name);
                row.createCell(3).setCellValue(tr.priority);
                row.createCell(4).setCellValue(tr.failReason == null ? "N/A" : tr.failReason);
            }
        }

        autoSizeColumns(sheet, headers.length);
    }

    private static void createMetricsSheet(Workbook wb, List<TestResult> results) {
        Sheet sheet = wb.createSheet("Execution Metrics");
        sheet.setDisplayGridlines(true);

        int total = results.size();
        int passed = 0;
        int failed = 0;
        int skipped = 0;
        long totalDuration = 0;

        for (TestResult tr : results) {
            totalDuration += tr.durationMs;
            if ("PASSED".equalsIgnoreCase(tr.status)) passed++;
            else if ("FAILED".equalsIgnoreCase(tr.status)) failed++;
            else if ("SKIPPED".equalsIgnoreCase(tr.status)) skipped++;
        }
        int blocked = 0; // standard skipped/blocked mapping

        double passRate = total == 0 ? 0.0 : (passed * 100.0) / total;

        Row titleRow = sheet.createRow(0);
        Cell titleCell = titleRow.createCell(0);
        titleCell.setCellValue("Automation Execution Summary Metrics");
        titleCell.setCellStyle(getHeaderStyle(wb));

        Row r1 = sheet.createRow(2);
        r1.createCell(0).setCellValue("Total Test Cases");
        r1.createCell(1).setCellValue(total);

        Row r2 = sheet.createRow(3);
        r2.createCell(0).setCellValue("Passed Test Cases");
        r2.createCell(1).setCellValue(passed);

        Row r3 = sheet.createRow(4);
        r3.createCell(0).setCellValue("Failed Test Cases");
        r3.createCell(1).setCellValue(failed);

        Row r4 = sheet.createRow(5);
        r4.createCell(0).setCellValue("Skipped Test Cases");
        r4.createCell(1).setCellValue(skipped);

        Row r5 = sheet.createRow(6);
        r5.createCell(0).setCellValue("Pass Percentage");
        r5.createCell(1).setCellValue(String.format("%.2f %%", passRate));

        Row r6 = sheet.createRow(7);
        r6.createCell(0).setCellValue("Total Duration");
        r6.createCell(1).setCellValue(String.format("%.2f s", totalDuration / 1000.0));

        autoSizeColumns(sheet, 2);
    }

    private static void createDefectSheet(Workbook wb, List<TestResult> results) {
        Sheet sheet = wb.createSheet("Defect Summary");
        sheet.setDisplayGridlines(true);

        Row headerRow = sheet.createRow(0);
        String[] headers = {"Test ID", "Module", "Failure Reason", "Stack Trace / Log Preview"};
        
        CellStyle headerStyle = getHeaderStyle(wb);
        for (int i = 0; i < headers.length; i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(headerStyle);
        }

        int rowNum = 1;
        for (TestResult tr : results) {
            if ("FAILED".equalsIgnoreCase(tr.status)) {
                Row row = sheet.createRow(rowNum++);
                row.createCell(0).setCellValue(tr.id);
                row.createCell(1).setCellValue(tr.module);
                row.createCell(2).setCellValue(tr.failReason);
                
                String stack = tr.stackTrace == null ? "" : tr.stackTrace;
                if (stack.length() > 300) {
                    stack = stack.substring(0, 300) + "... [truncated]";
                }
                row.createCell(3).setCellValue(stack);
            }
        }

        autoSizeColumns(sheet, headers.length);
    }

    private static void createPassRateSummarySheet(Workbook wb, List<TestResult> results) {
        Sheet sheet = wb.createSheet("Pass Rate Summary");
        sheet.setDisplayGridlines(true);

        Row headerRow = sheet.createRow(0);
        String[] headers = {"Module", "Total Tests", "Passed", "Failed", "Skipped", "Pass Rate (%)"};
        
        CellStyle headerStyle = getHeaderStyle(wb);
        for (int i = 0; i < headers.length; i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(headerStyle);
        }

        // Module aggregations
        Map<String, int[]> map = new LinkedHashMap<>(); // module -> [total, passed, failed, skipped]
        for (TestResult tr : results) {
            map.putIfAbsent(tr.module, new int[4]);
            int[] counts = map.get(tr.module);
            counts[0]++;
            if ("PASSED".equalsIgnoreCase(tr.status)) counts[1]++;
            else if ("FAILED".equalsIgnoreCase(tr.status)) counts[2]++;
            else if ("SKIPPED".equalsIgnoreCase(tr.status)) counts[3]++;
        }

        int rowNum = 1;
        for (Map.Entry<String, int[]> entry : map.entrySet()) {
            Row row = sheet.createRow(rowNum++);
            int[] counts = entry.getValue();
            row.createCell(0).setCellValue(entry.getKey());
            row.createCell(1).setCellValue(counts[0]);
            row.createCell(2).setCellValue(counts[1]);
            row.createCell(3).setCellValue(counts[2]);
            row.createCell(4).setCellValue(counts[3]);
            
            double rate = counts[0] == 0 ? 0.0 : (counts[1] * 100.0) / counts[0];
            row.createCell(5).setCellValue(String.format("%.2f %%", rate));
        }

        autoSizeColumns(sheet, headers.length);
    }

    private static CellStyle getHeaderStyle(Workbook wb) {
        CellStyle style = wb.createCellStyle();
        style.setFillForegroundColor(IndexedColors.GREY_80_PERCENT.getIndex());
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        Font font = wb.createFont();
        font.setColor(IndexedColors.WHITE.getIndex());
        font.setBold(true);
        font.setFontName("Segoe UI");
        style.setFont(font);
        style.setAlignment(HorizontalAlignment.CENTER);
        return style;
    }

    private static CellStyle getStatusStyle(Workbook wb, String status) {
        CellStyle style = wb.createCellStyle();
        Font font = wb.createFont();
        font.setBold(true);
        font.setFontName("Segoe UI");
        if ("PASSED".equalsIgnoreCase(status)) {
            style.setFillForegroundColor(IndexedColors.LIGHT_GREEN.getIndex());
            font.setColor(IndexedColors.DARK_GREEN.getIndex());
        } else if ("FAILED".equalsIgnoreCase(status)) {
            style.setFillForegroundColor(IndexedColors.ROSE.getIndex());
            font.setColor(IndexedColors.DARK_RED.getIndex());
        } else {
            style.setFillForegroundColor(IndexedColors.LIGHT_TURQUOISE.getIndex());
            font.setColor(IndexedColors.GREY_80_PERCENT.getIndex());
        }
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setFont(font);
        style.setAlignment(HorizontalAlignment.CENTER);
        return style;
    }

    private static void autoSizeColumns(Sheet sheet, int colCount) {
        for (int i = 0; i < colCount; i++) {
            sheet.autoSizeColumn(i);
        }
    }
}
