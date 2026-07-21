package com.plansphere.listeners;

import org.testng.IRetryAnalyzer;
import org.testng.ITestResult;

public class RetryAnalyzer implements IRetryAnalyzer {
    private int count = 0;
    private static final int MAX_RETRY_COUNT = 1; // Retry failed test cases once

    @Override
    public boolean retry(ITestResult result) {
        if (!result.isSuccess()) {
            if (count < MAX_RETRY_COUNT) {
                count++;
                System.out.println("Retrying test " + result.getName() + " with status "
                        + getStatusName(result.getStatus()) + " for the " + count + " time(s).");
                return true;
            }
        }
        return false;
    }

    private String getStatusName(int status) {
        switch (status) {
            case ITestResult.SUCCESS: return "SUCCESS";
            case ITestResult.FAILURE: return "FAILURE";
            case ITestResult.SKIP: return "SKIP";
            default: return "UNKNOWN";
        }
    }
}
