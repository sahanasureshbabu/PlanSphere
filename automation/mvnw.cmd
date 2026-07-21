@echo off
setlocal

set "MVN_VERSION=3.9.6"
set "MVN_DIR=%~dp0.maven"
set "MVN_HOME=%MVN_DIR%\apache-maven-%MVN_VERSION%"
set "MVN_ZIP=%MVN_DIR%\maven.zip"
set "MVN_URL=https://archive.apache.org/dist/maven/maven-3/%MVN_VERSION%/binaries/apache-maven-%MVN_VERSION%-bin.zip"

if not exist "%MVN_DIR%" mkdir "%MVN_DIR%"

if not exist "%MVN_HOME%\bin\mvn.cmd" (
    echo Maven wrapper: Maven not found. Downloading Maven %MVN_VERSION%...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%MVN_URL%' -OutFile '%MVN_ZIP%'"
    if errorlevel 1 (
        echo Error: Failed to download Maven.
        exit /b 1
    )
    
    echo Maven wrapper: Extracting Maven...
    powershell -Command "Expand-Archive -Path '%MVN_ZIP%' -DestinationPath '%MVN_DIR%' -Force"
    if errorlevel 1 (
        echo Error: Failed to extract Maven.
        exit /b 1
    )
    
    del "%MVN_ZIP%"
    echo Maven wrapper: Bootstrap complete.
)

"%MVN_HOME%\bin\mvn.cmd" %*
