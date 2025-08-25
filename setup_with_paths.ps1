# Financial-SDG-GARCH Environment Setup with Custom Paths
Write-Host "🚀 FINANCIAL-SDG-GARCH ENVIRONMENT SETUP WITH CUSTOM PATHS" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green

# Define paths
$pythonPath = "C:\Users\software\AppData\Local\Programs\Python\Python313\python.exe"
$rscriptPath = "C:\Program Files\R\R-4.5.1\bin\Rscript.exe"

Write-Host ""
Write-Host "🔍 Using custom Python and R paths..." -ForegroundColor Yellow
Write-Host "Python: $pythonPath" -ForegroundColor Cyan
Write-Host "R: $rscriptPath" -ForegroundColor Cyan
Write-Host ""

# Check if files exist
if (-not (Test-Path $pythonPath)) {
    Write-Host "❌ Python not found at: $pythonPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $rscriptPath)) {
    Write-Host "❌ Rscript not found at: $rscriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Both Python and R are available!" -ForegroundColor Green
Write-Host "Proceeding with package installation..." -ForegroundColor Yellow
Write-Host ""

# Install Python packages
Write-Host "📦 Installing Python packages..." -ForegroundColor Yellow
try {
    & $pythonPath quick_install_python.py
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Python packages installed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Python package installation failed" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error installing Python packages: $_" -ForegroundColor Red
}

Write-Host ""

# Install R packages
Write-Host "📦 Installing R packages..." -ForegroundColor Yellow
try {
    & $rscriptPath quick_install.R
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ R packages installed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ R package installation failed" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error installing R packages: $_" -ForegroundColor Red
}

Write-Host ""

# Run quick test
Write-Host "🧪 Running quick test..." -ForegroundColor Yellow
try {
    & $rscriptPath scripts/simulation_forecasting/simulate_nf_garch_quick_test.R
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Quick test completed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Quick test failed" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error running quick test: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 Setup complete! You can now run the full pipeline:" -ForegroundColor Green
Write-Host "  run_all.bat" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 To avoid using full paths in the future, add these to your system PATH:" -ForegroundColor Yellow
Write-Host "  C:\Users\software\AppData\Local\Programs\Python\Python313\" -ForegroundColor Cyan
Write-Host "  C:\Users\software\AppData\Local\Programs\Python\Python313\Scripts\" -ForegroundColor Cyan
Write-Host "  C:\Program Files\R\R-4.5.1\bin\" -ForegroundColor Cyan
Write-Host ""

Read-Host "Press Enter to continue"

