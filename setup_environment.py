#!/usr/bin/env python3
"""
Comprehensive Environment Setup Script for Financial-SDG-GARCH
This script checks for required software and guides through installation
"""

import subprocess
import sys
import os
import platform
import webbrowser
from pathlib import Path

def run_command(command):
    """Run a command and return success status"""
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr
    except FileNotFoundError:
        return False, "Command not found"

def check_python():
    """Check if Python is installed and accessible"""
    print("🔍 Checking Python installation...")
    
    # Try different Python commands
    python_commands = ['python', 'python3', 'py']
    python_found = False
    python_version = None
    
    for cmd in python_commands:
        success, output = run_command(f"{cmd} --version")
        if success:
            python_found = True
            python_version = output.strip()
            print(f"✅ Python found: {python_version}")
            return True, cmd, python_version
    
    print("❌ Python not found in PATH")
    return False, None, None

def check_r():
    """Check if R is installed and accessible"""
    print("🔍 Checking R installation...")
    
    # Try different R commands
    r_commands = ['Rscript', 'R']
    r_found = False
    r_version = None
    
    for cmd in r_commands:
        success, output = run_command(f"{cmd} --version")
        if success:
            r_found = True
            r_version = output.strip()
            print(f"✅ R found: {r_version}")
            return True, cmd, r_version
    
    print("❌ R not found in PATH")
    return False, None, None

def get_os_info():
    """Get operating system information"""
    system = platform.system()
    if system == "Windows":
        return "Windows"
    elif system == "Darwin":
        return "macOS"
    elif system == "Linux":
        return "Linux"
    else:
        return "Unknown"

def install_python_packages(python_cmd):
    """Install required Python packages"""
    print("\n📦 Installing Python packages...")
    
    required_packages = [
        "numpy", "pandas", "scikit-learn", "matplotlib", 
        "seaborn", "torch", "torchvision", "pyyaml", "pathlib2"
    ]
    
    failed_packages = []
    for package in required_packages:
        print(f"Installing {package}...")
        success, output = run_command(f"{python_cmd} -m pip install {package}")
        if success:
            print(f"  ✅ {package} installed successfully")
        else:
            print(f"  ❌ Error installing {package}: {output}")
            failed_packages.append(package)
    
    return failed_packages

def install_r_packages(r_cmd):
    """Install required R packages"""
    print("\n📦 Installing R packages...")
    
    # Create a temporary R script for package installation
    r_script = """
    required_packages <- c(
        "rugarch", "quantmod", "xts", "PerformanceAnalytics", "FinTS",
        "tidyverse", "dplyr", "tidyr", "stringr", "ggplot2", "openxlsx",
        "moments", "tseries", "forecast", "lmtest"
    )
    
    for (pkg in required_packages) {
        if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
            install.packages(pkg, dependencies = TRUE)
        }
    }
    """
    
    with open("temp_install.R", "w") as f:
        f.write(r_script)
    
    success, output = run_command(f'{r_cmd} temp_install.R')
    
    # Clean up
    if os.path.exists("temp_install.R"):
        os.remove("temp_install.R")
    
    if success:
        print("✅ R packages installed successfully")
        return []
    else:
        print(f"❌ Error installing R packages: {output}")
        return ["R packages"]

def provide_installation_instructions(os_type):
    """Provide installation instructions based on OS"""
    print(f"\n📋 INSTALLATION INSTRUCTIONS FOR {os_type.upper()}")
    print("=" * 50)
    
    if os_type == "Windows":
        print("\n🔧 Installing Python:")
        print("1. Go to https://www.python.org/downloads/")
        print("2. Download the latest Python version")
        print("3. Run the installer")
        print("4. ⚠️  IMPORTANT: Check 'Add Python to PATH' during installation")
        print("5. Complete the installation")
        
        print("\n🔧 Installing R:")
        print("1. Go to https://cran.r-project.org/bin/windows/base/")
        print("2. Download the latest R version for Windows")
        print("3. Run the installer")
        print("4. ⚠️  IMPORTANT: Add R to your system PATH")
        print("   - Find your R installation (usually C:\\Program Files\\R\\R-4.x.x\\bin)")
        print("   - Add this path to your system environment variables")
        
        print("\n🔧 Installing RStudio (Optional but Recommended):")
        print("1. Go to https://posit.co/download/rstudio-desktop/")
        print("2. Download RStudio for Windows")
        print("3. Install and launch")
        
    elif os_type == "macOS":
        print("\n🔧 Installing Python and R using Homebrew:")
        print("1. Install Homebrew if not already installed:")
        print("   /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
        print("2. Install Python and R:")
        print("   brew install python3 r")
        
    elif os_type == "Linux":
        print("\n🔧 Installing Python and R:")
        print("Ubuntu/Debian:")
        print("  sudo apt-get update")
        print("  sudo apt-get install python3 python3-pip r-base r-base-dev")
        print("\nCentOS/RHEL:")
        print("  sudo yum install python3 python3-pip R")
    
    print("\n🔄 After installation:")
    print("1. Close and reopen your terminal/command prompt")
    print("2. Run this script again to verify installation")
    print("3. The script will automatically install required packages")

def create_quick_setup_script():
    """Create a quick setup script for future use"""
    script_content = """#!/bin/bash
# Quick Setup Script for Financial-SDG-GARCH
echo "🚀 Quick Setup for Financial-SDG-GARCH"

# Check if Python is available
if command -v python3 &> /dev/null; then
    echo "✅ Python found, installing packages..."
    python3 quick_install_python.py
else
    echo "❌ Python not found. Please install Python first."
    exit 1
fi

# Check if R is available
if command -v Rscript &> /dev/null; then
    echo "✅ R found, installing packages..."
    Rscript quick_install.R
else
    echo "❌ R not found. Please install R first."
    exit 1
fi

# Run quick test
echo "🧪 Running quick test..."
Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R

echo "🎉 Setup complete! You can now run the full pipeline."
"""
    
    with open("quick_setup.sh", "w") as f:
        f.write(script_content)
    
    # Make it executable on Unix systems
    if platform.system() != "Windows":
        os.chmod("quick_setup.sh", 0o755)

def main():
    print("🚀 FINANCIAL-SDG-GARCH ENVIRONMENT SETUP")
    print("=" * 50)
    
    # Get OS information
    os_type = get_os_info()
    print(f"Operating System: {os_type}")
    
    # Check Python installation
    python_available, python_cmd, python_version = check_python()
    
    # Check R installation
    r_available, r_cmd, r_version = check_r()
    
    # If both are available, proceed with package installation
    if python_available and r_available:
        print("\n✅ Both Python and R are available!")
        print("Proceeding with package installation...")
        
        # Install Python packages
        failed_python = install_python_packages(python_cmd)
        
        # Install R packages
        failed_r = install_r_packages(r_cmd)
        
        # Summary
        print("\n" + "=" * 50)
        print("📊 INSTALLATION SUMMARY")
        print("=" * 50)
        
        if not failed_python and not failed_r:
            print("🎉 ALL INSTALLATIONS COMPLETED SUCCESSFULLY!")
            print("\nNext steps:")
            print("1. Run quick test: Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R")
            print("2. Run full pipeline: run_all.bat (Windows) or ./run_all.sh (Linux/Mac)")
            
            # Create quick setup script
            create_quick_setup_script()
            print("3. For future quick setup, run: ./quick_setup.sh")
            
        else:
            print("⚠️  Some installations failed:")
            if failed_python:
                print(f"  Python packages: {', '.join(failed_python)}")
            if failed_r:
                print(f"  R packages: {', '.join(failed_r)}")
            print("\nPlease check your internet connection and try again.")
    
    else:
        print("\n❌ Missing required software:")
        if not python_available:
            print("  - Python is not installed or not in PATH")
        if not r_available:
            print("  - R is not installed or not in PATH")
        
        # Provide installation instructions
        provide_installation_instructions(os_type)
        
        # Offer to open download pages
        print("\n🌐 Would you like to open the download pages?")
        print("1. Python: https://www.python.org/downloads/")
        print("2. R: https://cran.r-project.org/")
        print("3. RStudio: https://posit.co/download/rstudio-desktop/")
        
        try:
            choice = input("\nEnter choice (1-3) or press Enter to skip: ").strip()
            if choice == "1":
                webbrowser.open("https://www.python.org/downloads/")
            elif choice == "2":
                webbrowser.open("https://cran.r-project.org/")
            elif choice == "3":
                webbrowser.open("https://posit.co/download/rstudio-desktop/")
        except:
            pass

if __name__ == "__main__":
    main()

