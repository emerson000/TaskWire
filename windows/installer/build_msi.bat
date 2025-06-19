@echo off
setlocal EnableDelayedExpansion

set "WIX_PATH=C:\Program Files\WiX Toolset v6.0\bin"
set "DOTNET_WIX_PATH=%USERPROFILE%\.dotnet\tools"
set "SOURCE_DIR=%~dp0..\..\build\windows\x64\runner\Release"
set "OUTPUT_DIR=%~dp0"

for /f "tokens=2" %%a in ('type "%~dp0..\..\pubspec.yaml" ^| findstr /C:"version:"') do (
    set "VERSION=%%a"
    set "VERSION=!VERSION:+=.!"
)

if not exist "%WIX_PATH%" (
    if not exist "%DOTNET_WIX_PATH%\wix.exe" (
        echo WiX Toolset not found
        echo Installing WiX Toolset using dotnet tool...
        dotnet tool update --global wix
        if errorlevel 1 (
            echo Failed to install WiX Toolset
            exit /b 1
        )
    )
    set "WIX_PATH=%DOTNET_WIX_PATH%"
)

if not exist "%SOURCE_DIR%" (
    echo Build directory not found at "%SOURCE_DIR%"
    echo Please build the Flutter Windows app first
    exit /b 1
)

echo Building MSI installer with version %VERSION%...
"%WIX_PATH%\wix.exe" build -bindpath "%SOURCE_DIR%" -define Version=%VERSION% "%~dp0TaskWire.wxs" -arch x64
if errorlevel 1 goto :error

echo MSI installer created successfully
goto :end

:error
echo Failed to create MSI installer
exit /b 1

:end 