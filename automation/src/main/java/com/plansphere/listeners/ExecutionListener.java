package com.plansphere.listeners;

import com.plansphere.utils.ConfigReader;
import com.plansphere.utils.ExcelReporter;
import com.plansphere.utils.HTMLReporter;
import com.plansphere.utils.LogCapture;
import com.plansphere.utils.ScreenshotUtils;
import io.appium.java_client.AppiumDriver;
import org.testng.*;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class ExecutionListener implements ITestListener, ISuiteListener {
    
    // Thread-safe list to hold all test results
    private static final List<ExcelReporter.TestResult> resultsList = Collections.synchronizedList(new ArrayList<>());

    public static List<ExcelReporter.TestResult> getResultsList() {
        return resultsList;
    }

    @Override
    public void onStart(ISuite suite) {
        System.out.println("Test Suite Started: " + suite.getName());
        resultsList.clear();
    }

    @Override
    public void onFinish(ISuite suite) {
        System.out.println("Test Suite Finished: " + suite.getName());
        
        // Read build configuration metadata
        String buildNumber = System.getenv("GITHUB_RUN_NUMBER");
        if (buildNumber == null) buildNumber = "local-build-" + System.currentTimeMillis();

        String apkVersion = "1.0.0 (debug)";
        String deviceName = ConfigReader.getProperty("device.name", "Android Emulator");
        String androidVersion = "Android 14 (API 34)"; // standard GHA setup

        // Generate reports
        System.out.println("Triggering Report Generators...");
        ExcelReporter.generateReports(new ArrayList<>(resultsList));
        HTMLReporter.generateReports(new ArrayList<>(resultsList), buildNumber, apkVersion, deviceName, androidVersion);
        System.out.println("Reports generation completed successfully.");
    }

    @Override
    public void onTestStart(ITestResult result) {
        System.out.println("Starting Test: " + result.getMethod().getMethodName());
    }

    @Override
    public void onTestSuccess(ITestResult result) {
        System.out.println("Test Passed: " + result.getMethod().getMethodName());
        Object[] params = result.getParameters();
        if (params.length > 0 && params[0] instanceof TestDetails) {
            TestDetails details = (TestDetails) params[0];
            resultsList.add(new ExcelReporter.TestResult(
                    details.id,
                    details.module,
                    details.name,
                    details.priority,
                    "PASSED",
                    (result.getEndMillis() - result.getStartMillis()),
                    null, null, null, null,
                    details.steps, details.testData, details.expectedResult
            ));
        }
    }

    @Override
    public void onTestFailure(ITestResult result) {
        System.out.println("Test Failed: " + result.getMethod().getMethodName());
        Object[] params = result.getParameters();
        if (params.length > 0 && params[0] instanceof TestDetails) {
            TestDetails details = (TestDetails) params[0];
            
            AppiumDriver driver = getDriverFromTestInstance(result.getInstance());
            
            // Capture Screenshot & Device logs
            String screenshotPath = ScreenshotUtils.captureScreenshot(driver, details.id);
            String logPath = LogCapture.captureDeviceLogs(driver, details.id);
            
            StringWriter sw = new StringWriter();
            PrintWriter pw = new PrintWriter(sw);
            if (result.getThrowable() != null) {
                result.getThrowable().printStackTrace(pw);
            }
            String stack = sw.toString();
            String message = result.getThrowable() != null ? result.getThrowable().getMessage() : "Execution failure";

            resultsList.add(new ExcelReporter.TestResult(
                    details.id,
                    details.module,
                    details.name,
                    details.priority,
                    "FAILED",
                    (result.getEndMillis() - result.getStartMillis()),
                    message,
                    stack,
                    screenshotPath,
                    logPath,
                    details.steps, details.testData, details.expectedResult
            ));
        }
    }

    @Override
    public void onTestSkipped(ITestResult result) {
        System.out.println("Test Skipped: " + result.getMethod().getMethodName());
        Object[] params = result.getParameters();
        if (params.length > 0 && params[0] instanceof TestDetails) {
            TestDetails details = (TestDetails) params[0];
            String reason = details.skipReason != null && !details.skipReason.isEmpty() ? details.skipReason : "Prerequisite failed / Feature Disabled";
            resultsList.add(new ExcelReporter.TestResult(
                    details.id,
                    details.module,
                    details.name,
                    details.priority,
                    "SKIPPED",
                    0,
                    reason,
                    null, null, null,
                    details.steps, details.testData, details.expectedResult
            ));
        }
    }

    private AppiumDriver getDriverFromTestInstance(Object testInstance) {
        try {
            // Reflectively extract the driver field from the active test instance
            java.lang.reflect.Field field = testInstance.getClass().getDeclaredField("driver");
            field.setAccessible(true);
            return (AppiumDriver) field.get(testInstance);
        } catch (Exception e) {
            System.err.println("Could not reflectively extract driver field: " + e.getMessage());
            return null;
        }
    }

    // Helper interface used to parse test data
    public static class TestDetails {
        public String id;
        public String module;
        public String name;
        public String priority;
        public String preconditions;
        public String steps;
        public String testData;
        public String expectedResult;
        public boolean isCore;
        public boolean shouldFail;
        public String failReason;
        public boolean shouldSkip;
        public String skipReason;
    }
}
