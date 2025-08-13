#!/usr/bin/env python3
"""
Script to rename and move NF residual files to standardized naming convention.
"""
import os
import shutil
import re
from pathlib import Path

def standardize_filename(filename):
    """Standardize filename to the new convention."""
    # Remove .csv extension
    name = filename.replace('.csv', '')
    
    # Handle different naming patterns
    patterns = [
        # Pattern: sGARCH_sstd_fx_USDZAR_residuals_synthetic
        r'^([a-zA-Z]+)_([a-zA-Z]+)_([a-zA-Z]+)_([A-Z]+)_residuals_synthetic$',
        # Pattern: fx_USDZAR_residuals_sGARCH_sstd_residuals_synthetic_synthetic
        r'^([a-zA-Z]+)_([A-Z]+)_residuals_([a-zA-Z]+)_([a-zA-Z]+)_residuals_synthetic_synthetic$',
        # Pattern: fx_USDZAR_TS_CV_residuals_sGARCH_sstd_residuals_synthetic_synthetic
        r'^([a-zA-Z]+)_([A-Z]+)_TS_CV_residuals_([a-zA-Z]+)_([a-zA-Z]+)_residuals_synthetic_synthetic$',
        # Pattern: fx_USDZAR_Chrono_Split_residuals_sGARCH_sstd_residuals_synthetic_synthetic
        r'^([a-zA-Z]+)_([A-Z]+)_Chrono_Split_residuals_([a-zA-Z]+)_([a-zA-Z]+)_residuals_synthetic_synthetic$'
    ]
    
    for pattern in patterns:
        match = re.match(pattern, name)
        if match:
            if len(match.groups()) == 4:
                if match.group(1) in ['fx', 'equity']:
                    # Pattern 2, 3, 4: fx_USDZAR_residuals_sGARCH_sstd_residuals_synthetic_synthetic
                    asset_type = match.group(1)
                    asset = match.group(2)
                    config = match.group(3)
                    dist = match.group(4)
                    return f"{config}_{dist}_{asset_type}_{asset}_residuals_synthetic.csv"
                else:
                    # Pattern 1: sGARCH_sstd_fx_USDZAR_residuals_synthetic
                    config = match.group(1)
                    dist = match.group(2)
                    asset_type = match.group(3)
                    asset = match.group(4)
                    return f"{config}_{dist}_{asset_type}_{asset}_residuals_synthetic.csv"
    
    # If no pattern matches, return original name
    return filename

def main():
    source_dir = Path("nf_generated_residuals")
    target_dir = Path("data/residuals_by_model")
    
    if not source_dir.exists():
        print(f"Source directory {source_dir} does not exist")
        return
    
    # Create target directory if it doesn't exist
    target_dir.mkdir(parents=True, exist_ok=True)
    
    moved_files = []
    
    for file_path in source_dir.glob("*.csv"):
        old_name = file_path.name
        new_name = standardize_filename(old_name)
        
        # Convert to lowercase for config names
        parts = new_name.split('_')
        if len(parts) >= 2:
            config = parts[0].lower()
            if config == 'sgarch':
                config = 'sgarch'
            elif config == 'gjrgarch':
                config = 'gjrgarch'
            elif config == 'egarch':
                config = 'egarch'
            elif config == 'tgarch':
                config = 'tgarch'
            
            parts[0] = config
            new_name = '_'.join(parts)
        
        source_file = source_dir / old_name
        target_file = target_dir / new_name
        
        print(f"Moving: {old_name} -> {new_name}")
        
        # Use git mv if possible, otherwise copy and remove
        try:
            os.system(f'git mv "{source_file}" "{target_file}"')
            moved_files.append((old_name, new_name))
        except:
            shutil.copy2(source_file, target_file)
            source_file.unlink()
            moved_files.append((old_name, new_name))
    
    print(f"\nMoved {len(moved_files)} files")
    
    # Remove empty source directory
    if source_dir.exists() and not any(source_dir.iterdir()):
        source_dir.rmdir()
        print(f"Removed empty directory: {source_dir}")

if __name__ == "__main__":
    main()
