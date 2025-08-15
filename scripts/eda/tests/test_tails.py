#!/usr/bin/env python3
"""
Unit tests for tail estimation functions
"""

import numpy as np
import pandas as pd
from scipy.stats import pareto
import sys
import os

# Add parent directory to path to import eda_finance
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from eda_finance import hill_tail_index

def test_hill_increases_with_heavier_tail():
    """Test that Hill estimator increases with heavier tails"""
    np.random.seed(42)
    
    # Pareto(alpha): heavier tails for smaller alpha
    x1 = pareto.rvs(5, size=5000)   # lighter tail
    x2 = pareto.rvs(2, size=5000)   # heavier tail
    
    h1 = hill_tail_index(pd.Series(x1))
    h2 = hill_tail_index(pd.Series(x2))
    
    print(f"Hill index (alpha=5): {h1:.3f}")
    print(f"Hill index (alpha=2): {h2:.3f}")
    
    # Hill index should be smaller for heavier tails (smaller alpha in Pareto)
    assert h2 < h1, f"Hill index should decrease with heavier tails: {h1} vs {h2}"
    print("✅ Hill estimator correctly identifies heavier tails")

def test_hill_with_normal_distribution():
    """Test Hill estimator with normal distribution (should be finite)"""
    np.random.seed(42)
    
    # Normal distribution has finite moments
    x = np.random.normal(0, 1, 10000)
    h = hill_tail_index(pd.Series(x))
    
    print(f"Hill index (normal): {h:.3f}")
    
    # Should be finite and reasonable
    assert not np.isnan(h), "Hill index should not be NaN for normal distribution"
    assert h > 0, "Hill index should be positive"
    print("✅ Hill estimator works with normal distribution")

def test_hill_with_insufficient_data():
    """Test Hill estimator with insufficient data"""
    # Very small dataset
    x = pd.Series([1, 2, 3, 4, 5])
    h = hill_tail_index(x, threshold_quantile=0.95)
    
    # Should return NaN for insufficient data
    assert np.isnan(h), "Hill index should be NaN for insufficient data"
    print("✅ Hill estimator handles insufficient data correctly")

if __name__ == "__main__":
    print("Running Hill estimator tests...")
    test_hill_increases_with_heavier_tail()
    test_hill_with_normal_distribution()
    test_hill_with_insufficient_data()
    print("✅ All tests passed!")
