#!/usr/bin/env bash

# ==============================================================================
# Automated Exploratory Data Analysis Pipeline
# Strict read-only file discovery and reporting confined to ~/Downloads.
# ==============================================================================

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$@"
fi

DOWNLOADS_DIR="$HOME/Downloads"
mkdir -p "$DOWNLOADS_DIR"

echo "============================================================"
echo "           AUTOMATED CSV EXPLORATORY DATA ANALYSIS"
echo "============================================================"
echo "Search directory restricted to: $DOWNLOADS_DIR"

# ------------------------------------------------------------
# MODULE 1: FILE ACQUISITION & GUARDRAILS
# ------------------------------------------------------------

TARGET_FILE=""

while true; do
    echo
    printf "Enter CSV filename or keyword (or type 'Quit' to exit): "
    
    if ! read -r USER_INPUT </dev/tty 2>/dev/null; then
        read -r USER_INPUT
    fi
    
    USER_INPUT="$(echo "$USER_INPUT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\r//')"

    if [[ "${USER_INPUT,,}" == "quit" || "${USER_INPUT,,}" == "q" ]]; then
        echo "Execution terminated by user."
        exit 0
    fi

    if [[ -z "$USER_INPUT" ]]; then
        continue
    fi

    SEARCH_TERM="${USER_INPUT%.*}"

    MATCHES=()
    while IFS= read -r -d '' file; do
        MATCHES+=("$file")
    done < <(
        find "$DOWNLOADS_DIR" -maxdepth 2 -type f \
            -iname "*${SEARCH_TERM}*.csv" -print0 2>/dev/null
    )

    NUM_MATCHES=${#MATCHES[@]}

    if (( NUM_MATCHES == 0 )); then
        echo "Please make sure that the file is there in Downloads, and then run the script automation again."
        exit 1
    elif (( NUM_MATCHES == 1 )); then
        TARGET_FILE="${MATCHES[0]}"
        echo "Target file selected: $TARGET_FILE"
        break
    else
        echo "Multiple matching CSV files were found:"
        for i in "${!MATCHES[@]}"; do
            printf "  %d) %s\n" "$((i + 1))" "${MATCHES[$i]}"
        done

        while true; do
            printf "Select file index (1-%d): " "$NUM_MATCHES"
            
            if ! read -r CHOICE </dev/tty 2>/dev/null; then
                read -r CHOICE
            fi
            
            CHOICE="$(echo "$CHOICE" | tr -d '[:space:]\r')"
            if (( CHOICE >= 1 && CHOICE <= NUM_MATCHES )); then
                TARGET_FILE="${MATCHES[$((CHOICE - 1))]}"
                break 2
            fi
            echo "Invalid selection."
        done
    fi
done

RAW_FILENAME="$(basename "$TARGET_FILE")"
FILENAME="${RAW_FILENAME%.csv}"
REPORT_FILE="$DOWNLOADS_DIR/${FILENAME}_report.txt"

# ------------------------------------------------------------
# MODULE 5 (Part A): UNIFIED OUTPUT STREAM
# ------------------------------------------------------------
exec > >(tee "$REPORT_FILE") 2>&1

echo
echo "============================================================"
echo "                EXPLORATORY DATA ANALYSIS REPORT"
echo "============================================================"
echo "Source File : $TARGET_FILE"
echo "Timestamp   : $(date)"
echo "Report File : $REPORT_FILE"

# ------------------------------------------------------------
# MODULE 2: STRUCTURAL DIAGNOSTICS
# ------------------------------------------------------------

echo
echo "============================================================"
echo "MODULE 2: STRUCTURAL DIAGNOSTICS & SCHEMA AUDIT"
echo "============================================================"

awk '
function parse_csv(line, f,    n, len, i, char, in_q) {
    n = 1; f[1] = ""; in_q = 0; len = length(line)
    for (i = 1; i <= len; i++) {
        char = substr(line, i, 1)
        if (char == "\"") in_q = !in_q
        else if (char == "," && !in_q) { n++; f[n] = "" }
        else f[n] = f[n] char
    }
    return n
}
function clean(v) { gsub(/\r/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); gsub(/^"|"$/, "", v); return v }
function missing(v) { return (v == "" || v == "N/A" || v == "NA" || v == "null" || v == "NULL" || v == "None" || v == "NaN") }
function numeric(v) { return (v ~ /^-?([0-9]+([.][0-9]*)?|[.][0-9]+)$/) }

NR == 1 {
    num_cols = parse_csv($0, fields)
    for (i = 1; i <= num_cols; i++) headers[i] = clean(fields[i])
    next
}
{
    data_rows++
    raw_line = $0
    gsub(/\r/, "", raw_line)
    if (seen_rows[raw_line]++) duplicate_rows++

    parse_csv($0, fields)
    for (i = 1; i <= num_cols; i++) {
        val = clean(fields[i])
        if (missing(val)) null_count[i]++
        else {
            non_null_count[i]++
            if (numeric(val)) numeric_count[i]++
        }
    }
}
END {
    if (NR <= 1) { print "Error: CSV contains only headers or is empty."; exit 1 }

    print "Dataset Shape: " data_rows " rows, " num_cols " columns"
    print "Duplicate Rows: " (duplicate_rows + 0)

    print "\nColumn Index:"
    for (i = 1; i <= num_cols; i++) printf "  [%d] %s\n", i, headers[i]

    print "\nSchema and Missing Value Audit:"
    printf "%-5s %-28s %-15s %-15s %-15s\n", "Index", "Column Name", "Data Type", "Non-Null", "Null/NA"
    print "--------------------------------------------------------------------------------"

    num_feat = 0; cat_feat = 0
    for (i = 1; i <= num_cols; i++) {
        nn = non_null_count[i] + 0; nv = numeric_count[i] + 0; mn = null_count[i] + 0
        if (nn > 0 && nv == nn) { dtype = "Numeric"; num_feat++ } 
        else { dtype = "Categorical"; cat_feat++ }
        printf "%-5d %-28s %-15s %-15d %-15d\n", i, headers[i], dtype, nn, mn
    }
    print "\nFeature Summary:"
    print "  Numeric Features     : " num_feat
    print "  Categorical Features : " cat_feat
}' "$TARGET_FILE"

# ------------------------------------------------------------
# MODULE 3: ADVANCED STATISTICAL ENGINE
# ------------------------------------------------------------

echo
echo "============================================================"
echo "MODULE 3: ADVANCED STATISTICAL ENGINE"
echo "============================================================"

awk '
function parse_csv(line, f, n, len, i, char, in_q) {
    n = 1; f[1] = ""; in_q = 0; len = length(line)
    for (i = 1; i <= len; i++) {
        char = substr(line, i, 1)
        if (char == "\"") in_q = !in_q
        else if (char == "," && !in_q) { n++; f[n] = "" }
        else f[n] = f[n] char
    }
    return n
}
function clean(v) { gsub(/\r/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); gsub(/^"|"$/, "", v); return v }
function missing(v) { return (v == "" || v == "N/A" || v == "NA" || v == "null" || v == "NULL" || v == "None" || v == "NaN") }
function numeric(v) { return (v ~ /^-?([0-9]+([.][0-9]*)?|[.][0-9]+)$/) }
function absval(v) { return (v < 0 ? -v : v) }
function percentile(a, n, p, pos, idx, frac) {
    if (n == 1) return a[1]
    pos = 1 + (n - 1) * p; idx = int(pos); frac = pos - idx
    if (idx >= n) return a[n]
    return a[idx] + frac * (a[idx + 1] - a[idx])
}

NR == 1 {
    num_cols = parse_csv($0, fields)
    for (i = 1; i <= num_cols; i++) headers[i] = clean(fields[i])
    next
}
{
    parse_csv($0, fields)
    for (i = 1; i <= num_cols; i++) {
        val = clean(fields[i])
        if (!missing(val)) {
            non_null[i]++
            unique_vals[i SUBSEP val]++
            if (numeric(val)) {
                num_vals_count[i]++
                num_data[i SUBSEP NR] = val + 0
            }
        }
    }
}
END {
    target_c = 0; key_c = 0
    for (i = 1; i <= num_cols; i++) {
        nn = non_null[i] + 0; nv = num_vals_count[i] + 0; u_count = 0
        for (k in unique_vals) { split(k, p, SUBSEP); if (p[1] == i) u_count++ }
        is_num = (nn > 0 && nv == nn); is_key = (nn > 0 && u_count == nn)

        if (is_key) {
            key_c++
            print "[KEY DETECTED] " headers[i] " (100% unique non-null numeric values) - Excluded from aggregation."
        } else if (is_num) {
            target_c++; target[target_c] = i
        }
    }

    if (target_c == 0) { print "\nNo non-key numeric columns available for statistical analysis."; exit }

    print "\n------------------------------------------------------------"
    print "UNIVARIATE STATISTICS (NON-KEY NUMERICS)"
    print "------------------------------------------------------------"

    for (t = 1; t <= target_c; t++) {
        col = target[t]; n = 0; delete arr; delete freq
        for (r = 2; r <= NR; r++) {
            k = col SUBSEP r
            if (k in num_data) { n++; arr[n] = num_data[k] }
        }
        if (n == 0) continue

        for (x = 1; x <= n; x++) {
            for (y = x + 1; y <= n; y++) {
                if (arr[x] > arr[y]) { tmp = arr[x]; arr[x] = arr[y]; arr[y] = tmp }
            }
        }

        sum = 0; max_f = 0; mode_v = arr[1]; m_count = 0
        for (r = 1; r <= n; r++) {
            v = arr[r]; sum += v; freq[v]++
            if (freq[v] > max_f) { max_f = freq[v]; mode_v = v }
        }
        for (v in freq) { if (freq[v] == max_f) m_count++ }

        mean = sum / n
        median = percentile(arr, n, 0.50); q1 = percentile(arr, n, 0.25); q3 = percentile(arr, n, 0.75)
        iqr = q3 - q1; min_v = arr[1]; max_v = arr[n]; range_v = max_v - min_v

        sum_sq = 0; sum_abs = 0; sum_cube = 0
        l_fence = q1 - 1.5 * iqr; u_fence = q3 + 1.5 * iqr; out_c = 0

        for (r = 1; r <= n; r++) {
            v = arr[r]; diff = v - mean
            sum_sq += diff * diff; sum_abs += absval(diff); sum_cube += diff * diff * diff
            if (v < l_fence || v > u_fence) out_c++
        }

        variance = (n > 1 ? sum_sq / (n - 1) : 0); std_dev = sqrt(variance); mad = sum_abs / n
        skewness = 0
        if (n > 2 && std_dev > 0) {
            skewness = (n * n / ((n - 1) * (n - 2))) * ((sum_cube / n) / (std_dev * std_dev * std_dev))
        }
        if (skewness > 0.5) s_lbl = "Right-skewed"
        else if (skewness < -0.5) s_lbl = "Left-skewed"
        else s_lbl = "Symmetric"

        print "\nFeature           : " headers[col]
        printf "Mean              : %.6f\n", mean
        printf "Median (Q2)       : %.6f\n", median
        if (m_count > 1) print "Mode              : Multiple modes detected (rep: " mode_v ")"
        else if (max_f == 1) print "Mode              : No repeated value"
        else print "Mode              : " mode_v
        printf "Min / Max / Range : %.6f / %.6f / %.6f\n", min_v, max_v, range_v
        printf "Q1 / Q3 / IQR     : %.6f / %.6f / %.6f\n", q1, q3, iqr
        printf "Sample Variance   : %.6f\n", variance
        printf "Sample Std Dev (s): %.6f\n", std_dev
        printf "Mean Abs Dev (MAD): %.6f\n", mad
        printf "Skewness (g1)     : %.6f (%s)\n", skewness, s_lbl
        printf "Outlier Count     : %d (Tukey bounds: [%.6f, %.6f])\n", out_c, l_fence, u_fence
    }

    if (target_c >= 2) {
        print "\n------------------------------------------------------------"
        print "BIVARIATE CORRELATION ANALYSIS (PEARSON'\''S r)"
        print "------------------------------------------------------------"
        high_abs = -1; b_c1 = ""; b_c2 = ""

        for (a = 1; a <= target_c; a++) {
            c1 = target[a]
            for (b = a + 1; b <= target_c; b++) {
                c2 = target[b]
                sx = sy = sxy = sx2 = sy2 = pc = 0
                for (r = 2; r <= NR; r++) {
                    k1 = c1 SUBSEP r; k2 = c2 SUBSEP r
                    if ((k1 in num_data) && (k2 in num_data)) {
                        x = num_data[k1]; y = num_data[k2]
                        sx += x; sy += y; sxy += x * y
                        sx2 += x * x; sy2 += y * y; pc++
                    }
                }
                if (pc > 1) {
                    num = pc * sxy - sx * sy
                    den = sqrt((pc * sx2 - sx * sx) * (pc * sy2 - sy * sy))
                    if (den > 0) {
                        r_val = num / den
                        printf "%s vs %s : r = %.6f (n=%d)\n", headers[c1], headers[c2], r_val, pc
                        abs_r = absval(r_val)
                        if (abs_r > high_abs) { high_abs = abs_r; best_r = r_val; b_c1 = headers[c1]; b_c2 = headers[c2] }
                    }
                }
            }
        }
        if (b_c1 != "") {
            print "\nHighest Absolute Correlation:"
            printf "--> %s and %s : r = %.6f\n", b_c1, b_c2, best_r
        }
    }
}' "$TARGET_FILE"

# ------------------------------------------------------------
# MODULE 4: CATEGORICAL FEATURE ANALYSIS
# ------------------------------------------------------------

echo
echo "============================================================"
echo "MODULE 4: CATEGORICAL FEATURE ANALYSIS ENGINE"
echo "============================================================"

awk '
function parse_csv(line, f, n, len, i, char, in_q) {
    n = 1; f[1] = ""; in_q = 0; len = length(line)
    for (i = 1; i <= len; i++) {
        char = substr(line, i, 1)
        if (char == "\"") in_q = !in_q
        else if (char == "," && !in_q) { n++; f[n] = "" }
        else f[n] = f[n] char
    }
    return n
}
function clean(v) { gsub(/\r/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); gsub(/^"|"$/, "", v); return v }
function missing(v) { return (v == "" || v == "N/A" || v == "NA" || v == "null" || v == "NULL" || v == "None" || v == "NaN") }
function numeric(v) { return (v ~ /^-?([0-9]+([.][0-9]*)?|[.][0-9]+)$/) }

NR == 1 {
    num_cols = parse_csv($0, fields)
    for (i = 1; i <= num_cols; i++) headers[i] = clean(fields[i])
    next
}
{
    parse_csv($0, fields)
    for (i = 1; i <= num_cols; i++) {
        val = clean(fields[i])
        if (missing(val)) null_c[i]++
        else {
            nn_c[i]++
            if (numeric(val)) num_c[i]++
            cat_c[i SUBSEP val]++
        }
    }
}
END {
    cat_tot = 0
    for (i = 1; i <= num_cols; i++) {
        nn = nn_c[i] + 0; nv = num_c[i] + 0
        
        # If it is NOT 100% numeric, it gets evaluated for Categorical
        if (!(nn > 0 && nv == nn)) { 
            
            # Count unique string/mixed values
            u_count = 0
            for (k in cat_c) {
                split(k, p, SUBSEP)
                if (p[1] == i) u_count++
            }
            
            # Check if this categorical column is actually an ID/Key
            is_key = (nn > 0 && u_count == nn)
            
            if (is_key) {
                print "[KEY DETECTED] " headers[i] " (100% unique string/mixed values) - Excluded from categorical analysis."
            } else {
                cat_tot++; cat_idx[cat_tot] = i 
            }
        }
    }

    if (cat_tot == 0) { print "\nNo categorical columns identified for analysis."; exit }

    for (t = 1; t <= cat_tot; t++) {
        col = cat_idx[t]; nn = nn_c[col] + 0
        
        delete cats; c_tot = 0; max_f = 0; mode_c = ""
        for (k in cat_c) {
            split(k, p, SUBSEP)
            if (p[1] == col) {
                c_tot++; cats[c_tot] = p[2]; freq = cat_c[k]
                if (freq > max_f) { max_f = freq; mode_c = p[2] }
            }
        }
        
        card_ratio = (nn > 0 ? c_tot / nn : 0)
        dom_pct = (nn > 0 ? max_f * 100 / nn : 0)

        print "\n------------------------------------------------------------"
        print "Categorical Feature : " headers[col]
        print "Unique Categories   : " c_tot
        printf "Cardinality Ratio   : %.6f\n", card_ratio
        print "Mode Category       : " (mode_c == "" ? "N/A" : mode_c)
        
        if (dom_pct >= 80) dom_lbl = "Highly Dominated"
        else if (dom_pct >= 50) dom_lbl = "Moderately Dominated"
        else dom_lbl = "Balanced"
        
        printf "Dominance Detection : %s (Mode freq: %d, %.2f%%)\n", dom_lbl, max_f, dom_pct

        print "\nFrequency Distribution & Rare Detection:"
        printf "%-35s %-10s %-12s %-15s\n", "Category", "Count", "Percentage", "Status"
        print "----------------------------------------------------------------------"

        # Sort descending
        for (x = 1; x <= c_tot; x++) {
            for (y = x + 1; y <= c_tot; y++) {
                fx = cat_c[col SUBSEP cats[x]]; fy = cat_c[col SUBSEP cats[y]]
                if (fy > fx) { tmp = cats[x]; cats[x] = cats[y]; cats[y] = tmp }
            }
        }

        rare_count = 0
        for (x = 1; x <= c_tot; x++) {
            c_name = cats[x]; f = cat_c[col SUBSEP c_name]
            pct = (nn > 0 ? f * 100 / nn : 0)
            
            if (pct < 1.0) { stat = "Rare (<1%)"; rare_count++ } else { stat = "Normal" }
            
            disp = c_name
            if (length(disp) > 34) disp = substr(disp, 1, 31) "..."
            printf "%-35s %-10d %-11.2f%% %-15s\n", disp, f, pct, stat
        }
        print "\nTotal Rare Categories: " rare_count
    }
}' "$TARGET_FILE"

# ------------------------------------------------------------
# MODULE 5 (Part B): FINAL LOGGING COMPLETION
# ------------------------------------------------------------

echo
echo "============================================================"
echo "MODULE 5: AUTOMATED PLAIN-TEXT LOGGING COMPLETED"
echo "============================================================"
echo "The pipeline executed successfully."
echo "Data immutability preserved: No modifications made to source file."
echo "Full output mirrored and saved to:"
echo "$REPORT_FILE"
echo "============================================================"
