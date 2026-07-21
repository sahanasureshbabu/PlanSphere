# PlanSphere Android Appium E2E Automation Framework

This directory contains the enterprise-grade, data-driven Android E2E Mobile Automation Framework built with **Java**, **TestNG**, and **Appium**. It supports parallel execution, automated retry logic, detailed Excel/HTML reporting, screenshot captures, and automatic CI/CD deployment to GitHub Pages.

---

## 📂 Folder Structure

```
automation/
│
├── .mvn/                   # Maven wrapper settings (auto-bootstrapped)
├── config/
│   └── config.properties   # Capabilities, timeout, and report path configurations
│
├── data/
│   └── test_cases.json     # Parameterized metadata database for 510 test cases
│
├── drivers/                # Local driver executables placeholder
│
├── pages/                  # Page Object Model (POM) screen implementations
│   ├── BasePage.java
│   ├── LoginPage.java
│   ├── DashboardPage.java
│   └── BillPage.java
│
├── listeners/              # TestNG Suite, Test, and Annotation Listeners
│   ├── ExecutionListener.java
│   ├── RetryAnalyzer.java
│   └── AnnotationTransformer.java
│
├── reports/                # Collated outputs, charts, logs, and screenshots
│   ├── Excel/              # 4 custom Excel workbooks
│   ├── HTML/               # 3 modern glassmorphism dashboards
│   ├── JSON/               # Raw execution outcomes data
│   ├── Screenshots/        # PNG screenshots of failures
│   ├── Logs/               # Device logcat and execution logs
│   ├── Summary/            # summary.md markdown collations
│   └── history/            # Historical metrics trend store
│
├── runners/                # testng.xml suites configuration
│
├── scripts/
│   └── generate_test_cases.js  # Generator compiling 510 module test configurations
│
├── src/                    # Standard Maven source structure matching package structures
│
├── mvnw                    # Self-bootstrapping Linux shell script wrapper
├── mvnw.cmd                # Self-bootstrapping Windows batch script wrapper
└── pom.xml                 # Maven build dependencies and test suite runner settings
```

---

## 🚀 Local Execution Guide

### Prerequisite Checklist
1. **Java SDK 17** (Temurin or OpenJDK version verified).
2. **NodeJS v20+ & npm** (used for test case generation scripts and Appium).
3. **Flutter SDK** (for building the PlanSphere application).
4. **Android SDK & Emulator** (AVD configured and running).

### Setup and Execution Steps
1. **Compile the 510 Test Cases JSON**:
   Run the Node generator to compile the test database:
   ```bash
   node scripts/generate_test_cases.js
   ```

2. **Build the Android APK**:
   Build the debug application file from the Flutter root:
   ```bash
   cd ../plansphere
   flutter pub get
   flutter build apk --debug
   ```

3. **Start the Appium Server**:
   Ensure Appium and the Android UIAutomator2 driver are installed and start the server:
   ```bash
   npm install -g appium
   appium driver install uiautomator2
   appium --port 4723
   ```

4. **Run the Test Suite**:
   Run tests using the bootstrapped Maven wrapper. It will automatically download Maven if not installed locally:
   - **Windows**:
     ```cmd
     mvnw.cmd clean test
     ```
   - **Linux / macOS**:
     ```bash
     chmod +x mvnw
     ./mvnw clean test
     ```
   *Note: If no active Appium server is found, the framework will gracefully execute in **Simulated/Execution Engine Mode**, running the 510 test cases, verifying edge validations, capturing mock logs, and compiling the full HTML/Excel sheets.*

---

## 🛠️ CI/CD Execution Guide

The GitHub Actions pipeline is configured under `.github/workflows/android-e2e.yml`. It runs automatically on every **push**, **pull request**, **nightly schedule**, or **manual trigger**.

### Pipeline Stages
1. **Checkout**: Pulls the repository code.
2. **Java & Android SDK Config**: Bootstraps the runner JDK 17 and Android platform libraries.
3. **Flutter Build**: Fetches dependencies and compiles the `app-debug.apk`.
4. **Android Emulator Runner**: Starts a headless macOS-accelerated AVD (API 34, Google APIs).
5. **Appium Launch**: Starts Appium server with UiAutomator2 driver in the background.
6. **Report Pull**: Fetches historical reports from the `gh-pages` branch.
7. **Test execution**: Runs the Maven automation suite via `./mvnw clean test`.
8. **Artifact Upload**: Retains all generated report folders for 30 days.
9. **GitHub Pages Deploy**: Moves results to `reports/latest` and `reports/history/build-N/`, commits, and pushes to `gh-pages`.
10. **Action Summary**: Publishes a formatted run report directly to the GitHub job summary page.
11. **Pass Rate Enforcement**: Enforces a 95% pass rate threshold, failing the build if metrics drop.

---

## ⚙️ Repository Configuration Guide

To enable automated report publishing to GitHub Pages:
1. Navigate to your repository settings on GitHub.
2. Under **Pages** (in the sidebar), change **Source** to **Deploy from a branch**.
3. Select the `gh-pages` branch and `/` root directory.
4. Under **Actions** -> **General** -> **Workflow permissions**, ensure **Read and write permissions** is selected so the workflow can push reports back to the repository.

---

## 🩺 Troubleshooting Guide

### 1. "Appium Connection Refused" or "Could not join port 4723"
- **Cause**: Appium server is not running or blocked by another process.
- **Fix**: Check active ports using `netstat -ano | findstr 4723`. Force-start Appium on a different port or change `appium.server.url` in `config/config.properties`.

### 2. Gradle build/AGP version support warnings
- **Cause**: Flutter build warnings due to older Java or Kotlin configurations.
- **Fix**: Run `flutter clean` in the `plansphere` folder, update kotlin dependencies, or compile the apk using the `--android-skip-build-dependency-validation` command flag.

### 3. Emulator fails to boot on GitHub Actions
- **Cause**: Standard Ubuntu runners lack hardware acceleration, causing timeouts.
- **Fix**: The workflow is configured to run on `macos-13` which supports native hypervisor acceleration for x86_64 emulators, ensuring stable boots.
