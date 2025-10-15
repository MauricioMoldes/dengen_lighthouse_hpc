#!/bin/bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: $0 SAMPLE ANNOTATED_VCF RESULTS_DIR PROJECT_DIR"
    exit 1
fi

SAMPLE="$1"
ANNOTATED="$2"
RESULTS_DIR="$3"
PROJECT_DIR="$4"

mkdir -p "$RESULTS_DIR"

CHR_FILE="$PROJECT_DIR/config/chr_name_conv.txt"

echo "=== BEACON PIPELINE START: $SAMPLE ==="

# Step 1: Filter SNPs
FILTERED="$RESULTS_DIR/${SAMPLE}_SNP_filtered.vcf.gz"
echo "[FILTER: SNPs]"
bcftools filter -i 'TYPE="snp"' "$ANNOTATED" -Oz -o "$FILTERED"
tabix -p vcf "$FILTERED"

# Step 2: Decompose multi-allelics
DECOMPOSED="$RESULTS_DIR/${SAMPLE}_SNP_decomposed.vcf.gz"
echo "[DECOMPOSE]"
vt decompose "$FILTERED" -o "$DECOMPOSED"
tabix -p vcf "$DECOMPOSED"

# Step 3: Rename chromosomes
RENAMED="$RESULTS_DIR/${SAMPLE}_SNP_decomposed_renamed.vcf.gz"
echo "[RENAME CHROMOSOMES]"
bcftools annotate --rename-chrs "$CHR_FILE" "$DECOMPOSED" -Oz -o "$RENAMED"
tabix -p vcf "$RENAMED"

echo "=== BEACON PIPELINE COMPLETE: $RENAMED ==="

