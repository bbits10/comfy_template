@echo off
echo --- Simple SageAttention Installation ---

REM Delete existing SageAttention directory if it exists
if exist "SageAttention" (
    echo Deleting existing SageAttention directory...
    rmdir /s /q "SageAttention"
)

REM Clone the repository
echo Cloning SageAttention repository...
git clone https://github.com/thu-ml/SageAttention.git

REM Change to the directory and install
if exist "SageAttention" (
    echo Changing to SageAttention directory...
    cd SageAttention
    echo Installing SageAttention...
    python setup.py install
    
    if %ERRORLEVEL% EQU 0 (
        echo ✓ SageAttention installed successfully!
    ) else (
        echo ✗ Installation failed!
    )
) else (
    echo ✗ Failed to clone SageAttention repository!
)

echo --- Installation Complete ---
pause
