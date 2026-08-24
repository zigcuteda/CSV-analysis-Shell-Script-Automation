# Automated Exploratory Data Analysis (EDA) Pipeline

## Overview
This repository contains a robust, zero-dependency, Bash-based Exploratory Data Analysis (EDA) pipeline designed for CSV datasets. Built entirely using standard POSIX utilities (`bash`, `awk`, `sed`, `find`), it executes structural diagnostics, univariate statistics, bivariate correlation analysis, and categorical frequency distribution without requiring external libraries such as Python or Pandas.

## Core Operating Principles
* **Strict Directory Isolation:** File discovery and report generation are explicitly confined to the `~/Downloads` directory to prevent unintended system-wide traversal.
* **Data Immutability:** Source data is treated as strictly read-only. The script performs no row deletions, missing-value imputations, or structural modifications.
* **Unified Output Stream:** All standard output and standard error streams are mirrored. Output is displayed in the interactive terminal and simultaneously logged to a persistent plain-text report file.

## Pipeline Architecture
The pipeline is divided into five sequential modules:

* **Module 1: File Acquisition & Guardrails:** Implements fuzzy-search functionality for CSV discovery within the restricted directory. It includes error handling for unmatched files and an interactive menu for multiple matches.
* **Module 2: Structural Diagnostics:** Performs schema auditing. It calculates dataset dimensions, identifies identical duplicate rows, and categorizes variables into numerical or categorical structures based on a strict 100% non-null numerical threshold.
* **Module 3: Advanced Statistical Engine:** Evaluates numeric variables (excluding automatically detected primary keys). It calculates central tendencies, dispersion metrics, and bounds outliers using Tukey's fences. 
* **Module 4: Categorical Feature Analysis:** Evaluates non-numeric variables. It calculates cardinality ratios, identifies mode dominance, and categorizes rare variables (frequencies below 1%).
* **Module 5: Automated Logging:** Finalizes the execution and securely writes the in-memory analysis to the disk.

## Mathematical Engine
The statistical engine (Module 3) is driven by `awk` and implements the following formulas for exact analysis:

* **Sample Standard Deviation:** `s = sqrt( Σ(xi - x̄)² / (n-1) )`
* **Mean Absolute Deviation:** `MAD = (1/n) * Σ|xi - x̄|`
* **Skewness (Fisher-Pearson):** `g1 = [n² / ((n-1)(n-2))] * [Σ(xi - x̄)³ / (n * s³)]`
* **Pearson Correlation:** `r = (nΣxy - ΣxΣy) / sqrt([nΣx² - (Σx)²][nΣy² - (Σy)²])`

## Usage Instructions

1. Ensure your target CSV is located in the `~/Downloads` directory.
2. Open your terminal and create the script file (e.g., using `nano eda_pipeline.sh`).
3. Paste the source code and save the file.
4. Grant execution permissions by running: 
   ```bash
   chmod +x eda_pipeline.sh
   ```
5. Execute the pipeline by running: 
   ```bash
   ./eda_pipeline.sh
   ```
6. Follow the terminal prompts to select your dataset. The final report will be generated in the same directory as the source file.

## SWOT Analysis

| Area | Analysis |
| :--- | :--- |
| **Strengths** | **Zero-Dependency Architecture:** Requires no installations, environments, or package managers. It runs natively on almost any Unix-like system.<br><br>**Data Safety:** Strict immutability rules guarantee that source data is never corrupted or altered.<br><br>**Security:** Restricting operations to a single directory limits the risk of accidental file system exposure. |
| **Weaknesses** | **Computational Efficiency:** Because `awk` stores data internally for operations like sorting and matrix calculations, analyzing massively large CSV files will result in higher memory overhead compared to compiled binaries.<br><br>**Complex Parsing:** The internal CSV parser may struggle with highly complex edge cases, such as unescaped commas embedded inside multi-line quoted strings. |
| **Opportunities** | **CI/CD Integration:** The script can be adapted to run headlessly as a pre-commit hook or automated data-quality gate in continuous integration pipelines.<br><br>**Extensibility:** Provides a foundation that can be expanded to include terminal-based ASCII data visualizations or support for TSV/JSON formats. |
| **Threats** | **Environment Variations:** Specific implementations of `awk` (such as `gawk` vs `mawk` vs BSD `awk`) across different OS environments could introduce subtle floating-point arithmetic variations.<br><br>**Memory Exhaustion:** Relying entirely on memory for correlation arrays means the script could hit resource limits on devices with highly constrained RAM when fed excessively wide datasets. |
