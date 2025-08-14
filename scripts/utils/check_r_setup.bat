@echo off
REM Windows R Setup Check Script
REM This script helps diagnose and fix R command not found errors

echo === Financial-SDG-GARCH R Setup Check ===
echo.

echo 1. Checking R installation...
where R >nul 2>&1
if %errorlevel% equ 0 (
    echo ✓ R is found in PATH
    R --version
) else (
    echo ✗ R not found in PATH
    echo.
    echo 2. Searching for R installation...
    
    REM Common R installation paths on Windows
    set "R_PATHS=C:\Program Files\R\R-4.3.2\bin\x64;C:\Program Files\R\R-4.3.1\bin\x64;C:\Program Files\R\R-4.3.0\bin\x64;C:\Program Files\R\R-4.2.3\bin\x64;C:\Program Files\R\R-4.2.2\bin\x64;C:\Program Files\R\R-4.2.1\bin\x64;C:\Program Files\R\R-4.2.0\bin\x64;C:\Program Files\R\R-4.1.3\bin\x64;C:\Program Files\R\R-4.1.2\bin\x64;C:\Program Files\R\R-4.1.1\bin\x64;C:\Program Files\R\R-4.1.0\bin\x64;C:\Program Files\R\R-4.0.5\bin\x64;C:\Program Files\R\R-4.0.4\bin\x64;C:\Program Files\R\R-4.0.3\bin\x64;C:\Program Files\R\R-4.0.2\bin\x64;C:\Program Files\R\R-4.0.1\bin\x64;C:\Program Files\R\R-4.0.0\bin\x64"
    
    for %%p in (%R_PATHS%) do (
        if exist "%%p\R.exe" (
            echo Found R installation at: %%p
            echo.
            echo 3. Testing Rscript availability...
            "%%p\Rscript.exe" --version >nul 2>&1
            if !errorlevel! equ 0 (
                echo ✓ Rscript is available at: %%p\Rscript.exe
                echo.
                echo 4. Adding to PATH temporarily...
                set "PATH=%%p;%PATH%"
                echo ✓ R added to PATH for this session
                echo.
                echo 5. Testing R execution...
                Rscript --version
                if !errorlevel! equ 0 (
                    echo ✓ R is now working!
                    echo.
                    echo === SOLUTION ===
                    echo To permanently fix this issue:
                    echo 1. Open System Properties ^> Advanced ^> Environment Variables
                    echo 2. Add "%%p" to the PATH environment variable
                    echo 3. Restart your command prompt
                    echo.
                    echo Or run this command as administrator:
                    echo setx PATH "%%p;%%PATH%%"
                ) else (
                    echo ✗ R still not working after adding to PATH
                )
            ) else (
                echo ✗ Rscript not found at: %%p\Rscript.exe
            )
            goto :found_r
        )
    )
    
    echo ✗ No R installation found in common locations
    echo.
    echo === SOLUTION ===
    echo Please install R from: https://cran.r-project.org/bin/windows/base/
    echo After installation, add the R\bin\x64 directory to your PATH
    goto :end
)

:found_r
echo.
echo 6. Checking Rscript availability...
where Rscript >nul 2>&1
if %errorlevel% equ 0 (
    echo ✓ Rscript is found in PATH
    Rscript --version
) else (
    echo ✗ Rscript not found in PATH
    echo This will cause "R command not found" errors when running scripts
    echo.
    echo === SOLUTION ===
    echo Add the R bin directory to your PATH environment variable
)

:end
echo.
echo === Additional Troubleshooting ===
echo.
echo If you still get "R command not found" errors:
echo 1. Make sure R is installed and in PATH
echo 2. Try running: R --slave -e "source('script.R')" instead of Rscript
echo 3. Check if antivirus is blocking R execution
echo 4. Ensure you're running as administrator if needed
echo.
echo For more help, run: Rscript scripts/utils/setup_r_environment.R
echo.
pause
