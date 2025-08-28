#!/usr/bin/env python3
# NF Training Component
# Trains Normalizing Flow models on extracted residuals

import sys
import os
import subprocess

def main():
    print("=== RUNNING NF MODEL TRAINING ===")
    
    try:
        # Run the existing NF training script
        result = subprocess.run([
            "python", "scripts/model_fitting/train_nf_models.py"
        ], capture_output=True, text=True, check=True)
        
        print("✓ NF training completed successfully")
        print(result.stdout)
        
    except subprocess.CalledProcessError as e:
        print(f"❌ NF training failed: {e}")
        print(f"Error output: {e.stderr}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error in NF training: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
