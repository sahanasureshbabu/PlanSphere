const fs = require('fs');
const path = require('path');

const targetDir = path.join(__dirname, '..', 'data');
if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
}

const targetFile = path.join(targetDir, 'test_cases.json');

const modules = [
    { name: "Authentication", prefix: "AUTH", count: 40 },
    { name: "Authorization", prefix: "AZ", count: 30 },
    { name: "Registration", prefix: "REG", count: 20 },
    { name: "Profile Management", prefix: "PROFILE", count: 20 },
    { name: "Navigation", prefix: "NAV", count: 30 },
    { name: "Dashboard", prefix: "DASH", count: 20 },
    { name: "Forms", prefix: "FORM", count: 40 },
    { name: "CRUD Operations", prefix: "CRUD", count: 40 },
    { name: "Search", prefix: "SEARCH", count: 20 },
    { name: "Filters", prefix: "FILTER", count: 20 },
    { name: "Input Validation", prefix: "VALID", count: 40 },
    { name: "Error Handling", prefix: "ERR", count: 20 },
    { name: "Session Management", prefix: "SESS", count: 20 },
    { name: "Notifications", prefix: "NOTIF", count: 20 },
    { name: "File Upload", prefix: "FILE", count: 20 },
    { name: "Offline Handling", prefix: "OFFLINE", count: 10 },
    { name: "Accessibility", prefix: "ACCESS", count: 20 },
    { name: "Responsive UI", prefix: "RESP", count: 10 },
    { name: "Performance Smoke Tests", prefix: "PERF", count: 20 },
    { name: "Regression Suite", prefix: "REGRESS", count: 50 }
];

const testCases = [];

// Specific tests to match user's requested failed/skipped example
const specialCases = {
    "TC_AUTH_010": {
        shouldFail: true,
        failReason: "OTP validation mismatch",
        steps: "1. Navigate to OTP screen\n2. Enter incorrect OTP code\n3. Click Verify button",
        expectedResult: "Inline error message displaying validation mismatch is shown"
    },
    "TC_FORM_008": {
        shouldFail: true,
        failReason: "Validation message missing",
        steps: "1. Open Add Bill screen\n2. Leave mandatory Title field empty\n3. Click Save button",
        expectedResult: "Error icon and mandatory field validation message is displayed under Title input"
    },
    "TC_FILE_002": {
        shouldFail: true,
        failReason: "Application crash",
        steps: "1. Open document scan/upload section\n2. Choose a file larger than 50MB\n3. Click Upload",
        expectedResult: "Upload is blocked with clean error toast; app remains stable"
    },
    "TC_NOTIF_004": { // Note: TC_NOTIFICATION_004 in user's prompt, will match NOTIF prefix
        shouldSkip: true,
        skipReason: "Feature Disabled",
        steps: "1. Navigate to Settings page\n2. Attempt to toggle Push Notification channel permissions",
        expectedResult: "Permission dialog is shown to user"
    }
};

modules.forEach(mod => {
    for (let i = 1; i <= mod.count; i++) {
        const id = `TC_${mod.prefix}_${String(i).padStart(3, '0')}`;
        
        let priority = "MEDIUM";
        if (i % 5 === 1) priority = "HIGH";
        if (i % 8 === 0) priority = "LOW";
        
        // Define default values
        let name = `${mod.name} Functional Validation - Scenario ${i}`;
        let preconditions = "App is launched and user session is active";
        let steps = `1. Navigate to ${mod.name} module\n2. Perform functional operation flow ${i}\n3. Observe UI updates and device logs`;
        let testData = `mode: auto, value: ${i * 100}, flag: test_run_${i}`;
        let expectedResult = `Module responds correctly to operation flow ${i} without exceptions`;
        let shouldFail = false;
        let failReason = "";
        let shouldSkip = false;
        let skipReason = "";
        let isCore = false;

        // Customise some core/live tests
        if (mod.prefix === "AUTH") {
            preconditions = "App is launched and user is on Onboarding/Login page";
            if (i === 1) {
                name = "Valid Login";
                isCore = true;
                steps = "1. Enter valid email 'admin@plansphere.com'\n2. Enter valid password 'admin123'\n3. Click 'Sign In' button";
                testData = "email: admin@plansphere.com, password: admin123";
                expectedResult = "User session is initialized; redirected to Dashboard page";
            } else if (i === 2) {
                name = "Logout Flow";
                isCore = true;
                steps = "1. Open Profile menu\n2. Scroll and click 'Logout' button\n3. Confirm dialog";
                expectedResult = "User session token is cleared; redirected back to Login screen";
            }
        } else if (mod.prefix === "REG" && i === 1) {
            name = "Successful Registration";
            isCore = true;
            steps = "1. Tap on Registration switch link\n2. Fill Name 'New User', Email 'new@plansphere.com', and password 'secure123'\n3. Tap 'Register'";
            testData = "name: New User, email: new@plansphere.com, password: secure123";
            expectedResult = "Registration toast message displayed; redirected to login panel";
        } else if (mod.prefix === "PROFILE" && i === 5) {
            name = "Update Profile Details";
            isCore = true;
            steps = "1. Open Profile tab\n2. Modify display name to 'Updated Admin'\n3. Save changes";
            testData = "name: Updated Admin";
            expectedResult = "Success banner shown; name dynamically updates on dashboard header";
        } else if (mod.prefix === "SEARCH" && i === 3) {
            name = "Search Existing Record";
            isCore = true;
            steps = "1. Navigate to Search screen\n2. Enter keyword 'MacBook'\n3. Tap Search button";
            testData = "keyword: MacBook";
            expectedResult = "Related bills and documents for 'MacBook' are displayed in the results list";
        } else if (mod.prefix === "FORM" && i === 1) {
            name = "Add Bill Form - Core Validation";
            isCore = true;
            steps = "1. Navigate to Add Bill screen\n2. Enter product 'iPhone 16'\n3. Select Category 'Electronics'\n4. Select Bill Type 'Warranty Bill'\n5. Enter amount '1200'\n6. Save bill";
            testData = "product: iPhone 16, category: Electronics, type: Warranty Bill, amount: 1200";
            expectedResult = "Bill is saved successfully; shows up in Dashboard summary";
        }

        // Apply special cases for fail/skip
        if (specialCases[id]) {
            shouldFail = specialCases[id].shouldFail || false;
            failReason = specialCases[id].failReason || "";
            shouldSkip = specialCases[id].shouldSkip || false;
            skipReason = specialCases[id].skipReason || "";
            if (specialCases[id].steps) steps = specialCases[id].steps;
            if (specialCases[id].expectedResult) expectedResult = specialCases[id].expectedResult;
        } else {
            // Generate some random low priority failures/skips to make up the metrics realistically
            // But keeping it strictly within safety limits (e.g. 5 failures, 2 skips total)
            if (mod.prefix === "VALID" && i === 15) {
                shouldFail = true;
                failReason = "Numeric boundary validation allowed overflow";
                steps = "1. Open profile form\n2. Enter salary/amount as '9999999999999'\n3. Save form";
                expectedResult = "System flags error or clips number within bounds; does not save";
            }
            if (mod.prefix === "ERR" && i === 3) {
                shouldFail = true;
                failReason = "Unhandled NullPointerException on empty list index";
                steps = "1. Navigate to settings\n2. Clear all cache\n3. Instantly reload empty list";
                expectedResult = "Empty state placeholder is shown cleanly";
            }
            if (mod.prefix === "OFFLINE" && i === 5) {
                shouldSkip = true;
                skipReason = "Requires Airplane Mode automated hardware toggling";
            }
        }

        testCases.push({
            id,
            module: mod.name,
            name,
            priority,
            preconditions,
            steps,
            testData,
            expectedResult,
            isCore,
            shouldFail,
            failReason,
            shouldSkip,
            skipReason
        });
    }
});

fs.writeFileSync(targetFile, JSON.stringify(testCases, null, 4), 'utf8');
console.log(`Successfully generated ${testCases.length} test cases in ${targetFile}`);
