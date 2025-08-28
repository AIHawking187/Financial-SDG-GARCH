#!/bin/bash
# Bash script to run the full pipeline

set -e  # Exit on any error

echo "Starting Financial-SDG-GARCH pipeline..."

# Setup
echo "Setting up environment..."
make setup

# Run pipeline stages
echo "Running EDA..."
make eda

echo "Fitting GARCH models..."
make fit-garch

echo "Extracting residuals..."
make extract-residuals

echo "Training NF models..."
make train-nf

echo "Evaluating NF models..."
make eval-nf

echo "Simulating NF-GARCH..."
make simulate-nf-garch

echo "Running forecasts..."
make forecast

echo "Evaluating forecasts..."
make eval-forecasts

echo "Running stylized fact tests..."
make stylized

echo "Running VaR backtesting..."
make var

echo "Running stress tests..."
make stress

echo "Pipeline complete!"
