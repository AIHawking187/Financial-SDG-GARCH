#!/usr/bin/env python3
# NF Evaluation Component
# Evaluates trained Normalizing Flow models

import sys
import os
import subprocess

def main():
    print("=== RUNNING NF MODEL EVALUATION ===")
    
    try:
        # Run the existing NF evaluation script
        result = subprocess.run([
            "python", "scripts/model_fitting/evaluate_nf_fit.py"
        ], capture_output=True, text=True, check=True)
        
        print("✓ NF evaluation completed successfully")
        print(result.stdout)
        
    except subprocess.CalledProcessError as e:
        print(f"❌ NF evaluation failed: {e}")
        print(f"Error output: {e.stderr}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error in NF evaluation: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
