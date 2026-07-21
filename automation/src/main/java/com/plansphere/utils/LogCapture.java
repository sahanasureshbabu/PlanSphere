package com.plansphere.utils;

import io.appium.java_client.AppiumDriver;
import org.openqa.selenium.logging.LogEntry;

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.util.List;
import java.util.logging.Level;

public class LogCapture {

    /**
     * Captures adb logcat output from the device and saves it.
     * @param driver Active Appium driver.
     * @param testCaseId ID of the test case.
     * @return Relative path to the saved logs file.
     */
    public static String captureDeviceLogs(AppiumDriver driver, String testCaseId) {
        if (driver == null) {
            return null;
        }

        String logsDir = ConfigReader.getProperty("logs.dir", "reports/Logs");
        File dir = new File(logsDir);
        if (!dir.exists()) {
            dir.mkdirs();
        }

        String filename = testCaseId + "_" + System.currentTimeMillis() + "_device.log";
        File destination = new File(dir, filename);

        try {
            List<LogEntry> logEntries = driver.manage().logs().get("logcat").getAll();
            try (PrintWriter writer = new PrintWriter(new FileWriter(destination))) {
                for (LogEntry entry : logEntries) {
                    writer.println(entry.getTimestamp() + " [" + entry.getLevel() + "] " + entry.getMessage());
                }
            }
            System.out.println("Device logcat captured: " + destination.getAbsolutePath());
            return "Logs/" + filename;
        } catch (Exception e) {
            // Logcat might not be supported or authorized in all capabilities/drivers
            // Save stacktrace fallback
            try (PrintWriter writer = new PrintWriter(new FileWriter(destination))) {
                writer.println("Failed to capture active logcat from driver: " + e.getMessage());
                writer.println("Check Appium log level permissions or emulator setup.");
            } catch (Exception ex) {
                // ignore
            }
            return "Logs/" + filename;
        }
    }

    /**
     * Captures dynamic framework error log.
     */
    public static String captureFrameworkLog(String testCaseId, String logContent) {
        String logsDir = ConfigReader.getProperty("logs.dir", "reports/Logs");
        File dir = new File(logsDir);
        if (!dir.exists()) {
            dir.mkdirs();
        }

        String filename = testCaseId + "_" + System.currentTimeMillis() + "_framework.log";
        File destination = new File(dir, filename);

        try (PrintWriter writer = new PrintWriter(new FileWriter(destination))) {
            writer.println("Framework Execution Log for " + testCaseId);
            writer.println("Timestamp: " + System.currentTimeMillis());
            writer.println("----------------------------------------");
            writer.println(logContent);
            return "Logs/" + filename;
        } catch (Exception e) {
            return null;
        }
    }
}
