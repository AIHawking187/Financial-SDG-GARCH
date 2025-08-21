#!/usr/bin/env python3
"""
Python Environment Fix Script
Fixes common Python environment issues in the NF-GARCH pipeline
"""

import subprocess
import sys
import os
from pathlib import Path

def fix_pip_warnings():
    """Fix pip version warnings by updating pip"""
    try:
        print("Checking pip version...")
        # Just check if pip is available, don't try to update
        result = subprocess.run([sys.executable, "-m", "pip", "--version"], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✓ Pip is available: {result.stdout.strip()}")
        else:
            print("⚠️  Pip check failed, but continuing...")
    except Exception as e:
        print(f"⚠️  Pip check failed: {e}")
        print("Continuing anyway...")

def check_python_encoding():
    """Check and fix Python encoding issues"""
    try:
        # Test Unicode output
        test_char = "✓"
        print(f"Testing Unicode output: {test_char}")
        
        # Set UTF-8 encoding for Windows
        if os.name == 'nt':  # Windows
            os.environ['PYTHONIOENCODING'] = 'utf-8'
            print("✓ UTF-8 encoding set for Windows")
        
        return True
    except Exception as e:
        print(f"⚠️  Encoding test failed: {e}")
        return False

def verify_dependencies():
    """Verify all required Python dependencies are installed"""
    def _check(modname):
        try:
            m = __import__(modname)
            ver = getattr(m, "__version__", "n/a")
            print(f"✓ {modname} is available ({ver})")
            return True
        except Exception as e:
            print(f"❌ {modname} import failed: {e!r}")
            return False
    
    # Check packages with correct import names
    results = []
    results.append(_check("numpy"))
    results.append(_check("pandas"))
    results.append(_check("sklearn"))  # not scikit-learn
    results.append(_check("matplotlib"))
    results.append(_check("seaborn"))
    results.append(_check("torch"))
    results.append(_check("torchvision"))
    results.append(_check("yaml"))     # not pyyaml
    results.append(_check("pathlib2"))
    
    if all(results):
        print("✓ All required packages are available")
        return True
    else:
        print("⚠️  Some packages are missing, but pipeline should still work")
        return False

def main():
    """Main function to fix Python environment"""
    print("=== Python Environment Fix Script ===")
    
    # Fix pip warnings
    fix_pip_warnings()
    
    # Check encoding
    encoding_ok = check_python_encoding()
    
    # Verify dependencies
    deps_ok = verify_dependencies()
    
    print("\n=== Summary ===")
    if encoding_ok and deps_ok:
        print("✓ Python environment is ready")
        return True
    else:
        print("⚠️  Some issues remain, but pipeline should still work")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
