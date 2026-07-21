package com.plansphere.utils;

import io.appium.java_client.AppiumDriver;
import org.apache.commons.io.FileUtils;
import org.openqa.selenium.OutputType;
import org.openqa.selenium.TakesScreenshot;

import java.io.File;
import java.io.IOException;
import java.nio.file.Paths;

public class ScreenshotUtils {

    /**
     * Captures a screenshot from the active Appium session and saves it.
     * @param driver Active Appium driver.
     * @param testCaseId ID of the test case (e.g. TC_AUTH_010).
     * @return Relative path to the saved screenshot (from reports base dir).
     */
    public static String captureScreenshot(AppiumDriver driver, String testCaseId) {
        if (driver == null) {
            return null;
        }

        String screenshotDir = ConfigReader.getProperty("screenshots.dir", "reports/Screenshots");
        File dir = new File(screenshotDir);
        if (!dir.exists()) {
            dir.mkdirs();
        }

        String filename = testCaseId + "_" + System.currentTimeMillis() + ".png";
        File destination = new File(dir, filename);

        try {
            File source = ((TakesScreenshot) driver).getScreenshotAs(OutputType.FILE);
            FileUtils.copyFile(source, destination);
            System.out.println("Screenshot captured: " + destination.getAbsolutePath());
            
            // Return relative path from reports directory
            // e.g. reports/Screenshots/TC_AUTH_010_123.png -> Screenshots/TC_AUTH_010_123.png
            return "Screenshots/" + filename;
        } catch (IOException e) {
            System.err.println("Failed to capture screenshot: " + e.getMessage());
            return null;
        }
    }
}
