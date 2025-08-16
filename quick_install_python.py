#!/usr/bin/env python3
"""
Quick Installation Script for Python Dependencies
This script installs all required Python packages for the Financial-SDG-GARCH pipeline
"""

import subprocess
import sys
import os

def run_command(command):
    """Run a command and return success status"""
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr

def install_package(package):
    """Install a Python package"""
    print(f"Installing {package}...")
    success, output = run_command(f"{sys.executable} -m pip install {package}")
    if success:
        print(f"  ✅ {package} installed successfully")
    else:
        print(f"  ❌ Error installing {package}: {output}")
    return success

def check_package(package):
    """Check if a package is available"""
    try:
        __import__(package)
        print(f"✅ {package} is available")
        return True
    except ImportError:
        print(f"❌ {package} is missing")
        return False

def main():
    print("=== QUICK PYTHON INSTALLATION FOR FINANCIAL-SDG-GARCH ===\n")
    
    # Required packages
    required_packages = [
        "numpy",
        "pandas", 
        "scikit-learn",
        "matplotlib",
        "seaborn",
        "torch",
        "torchvision",
        "pyyaml",
        "pathlib2"
    ]
    
    print("Installing required Python packages...\n")
    
    # Install packages
    failed_packages = []
    for package in required_packages:
        if not install_package(package):
            failed_packages.append(package)
    
    print("\n=== INSTALLATION CHECK ===\n")
    
    # Check installation
    missing_packages = []
    for package in required_packages:
        # Convert package name to import name
        import_name = package.replace("-", "_")
        if not check_package(import_name):
            missing_packages.append(package)
    
    # Environment check
    print("\n=== ENVIRONMENT CHECK ===\n")
    print(f"Python version: {sys.version}")
    print(f"Python executable: {sys.executable}")
    print(f"Working directory: {os.getcwd()}")
    
    # Check if pip is available
    success, output = run_command(f"{sys.executable} -m pip --version")
    if success:
        print("✅ pip is available")
    else:
        print("❌ pip is not available")
    
    # Summary
    print("\n=== INSTALLATION SUMMARY ===\n")
    if len(missing_packages) == 0 and len(failed_packages) == 0:
        print("🎉 ALL PYTHON PACKAGES INSTALLED SUCCESSFULLY!")
        print("Your Python environment is ready for the NF-GARCH pipeline.\n")
        print("Next steps:")
        print("1. Run R installation: Rscript quick_install.R")
        print("2. Run quick test: Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R")
        print("3. Run full pipeline: run_all.bat (Windows) or ./run_all.sh (Linux/Mac)")
    else:
        print("⚠️  Some packages failed to install:")
        if failed_packages:
            print(f"  Failed installations: {', '.join(failed_packages)}")
        if missing_packages:
            print(f"  Missing packages: {', '.join(missing_packages)}")
        print("\nPlease check your internet connection and try again.")

if __name__ == "__main__":
    main()
