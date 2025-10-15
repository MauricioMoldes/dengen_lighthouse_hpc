#!/bin/bash
set -euo pipefail

# =======================
# DENGEN LIGHTHOUSE HPC WRAPPER
# =======================
# Modes:
#   - sequential: process samples one by one, final JSON dump at end
#   - per-sample-clean: process each sample, dump JSON, reset DB after each
#   - parallel-batch: process samples in batches, max N concurrent jobs

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 MODE [NUM_THREADS]"
    echo "MODE: sequential | per-sample-clean | parallel-batch"
    exit 1
fi

MODE="$1"
NUM_THREADS="${2:-10}"  # default parallel jobs

# -----------------------
# Project Directories
# -----------------------
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="$PROJECT_DIR/data"
TMP_DIR="$DATA_DIR/tmp"
OUTPUT_DIR="$DATA_DIR/output"
CONFIG_DIR="$PROJECT_DIR/config"
SINGULARITY_DIR="$PROJECT_DIR/singularity"
PIPELINE_DIR="$PROJECT_DIR/pipeline"

HOSTS_FILE="$CONFIG_DIR/hosts.txt"
CHR_FILE="$CONFIG_DIR/chr_name_conv.txt"

MONGO_SIF="$SINGULARITY_DIR/beacon2-db.sif"
TOOLS_SIF="$SINGULARITY_DIR/beacon2-tools.sif"
BEACON_PIPELINE="$PIPELINE_DIR/beacon_pipeline.sh"

# -----------------------
# Sample list
# -----------------------
SAMPLES_LIST="$DATA_DIR/dengen_anonymous_list_samples.txt"

if [[ ! -f "$SAMPLES_LIST" ]]; then
    echo "Sample list not found: $SAMPLES_LIST"
    exit 1
fi

mkdir -p "$TMP_DIR" "$OUTPUT_DIR"

# -----------------------
# Start MongoDB container
# -----------------------
singularity exec \
    --bind "$DATA_DIR/mongo_data:/data/db" \
    "$MONGO_SIF" \
    mongod --bind_ip_all --port 27017 &

MONGO_PID=$!
sleep 30

# Create root user (once)
singularity exec \
    --bind "$DATA_DIR/mongo_data:/data/db" \
    "$MONGO_SIF" \
    mongosh --host localhost --port 27017 --eval "use admin; db.createUser({user:'root', pwd:'example', roles:[{role:'root', db:'admin'}]});"

# -----------------------
# Function to run one sample
# -----------------------
run_sample() {
    local SAMPLE="$1"
    echo "===== Processing sample: $SAMPLE ====="

    ANNOTATED="$DATA_DIR/vcfs/${SAMPLE}_annotated.vcf.gz"

    "$BEACON_PIPELINE" "$SAMPLE" "$ANNOTATED" "$TMP_DIR" "$PROJECT_DIR"

    cp "$TMP_DIR/${SAMPLE}_SNP_decomposed_renamed.vcf.gz" "$DATA_DIR/"
    chmod 644 "$DATA_DIR/${SAMPLE}_SNP_decomposed_renamed.vcf.gz"
    chgrp external-rh_rh_gm "$DATA_DIR/${SAMPLE}_SNP_decomposed_renamed.vcf.gz"

    singularity exec \
        --bind "$DATA_DIR:/usr/src/app/files/vcf/files_to_read" \
        --bind "$HOSTS_FILE:/etc/hosts" \
        "$TOOLS_SIF" \
        bash -c "cd /usr/src/app/ && python genomicVariations_vcf.py"

    rm -f "$TMP_DIR/${SAMPLE}"_*

    if [[ "$MODE" == "per-sample-clean" ]]; then
        SAMPLE_OUTDIR="$OUTPUT_DIR/$SAMPLE"
        mkdir -p "$SAMPLE_OUTDIR"
        singularity exec \
            --bind "$DATA_DIR/mongo_data:/data/db" \
            --bind "$SAMPLE_OUTDIR:/output" \
            "$MONGO_SIF" \
            mongoexport \
                --jsonArray \
                --uri "mongodb://root:example@127.0.0.1:27017/beacon?authSource=admin" \
                --collection genomicVariations \
                --out /output/genomicVariations.json

        singularity exec \
            --bind "$DATA_DIR/mongo_data:/data/db" \
            "$MONGO_SIF" \
            mongo admin -u root -p example --eval "db.getSiblingDB('beacon').genomicVariations.drop()"
    fi

    echo "===== Completed: $SAMPLE ====="
}

# -----------------------
# Execute Mode
# -----------------------
case "$MODE" in
    sequential|per-sample-clean)
        while read -r SAMPLE; do
            run_sample "$SAMPLE"
        done < "$SAMPLES_LIST"
        ;;
    parallel-batch)
        count=0
        while read -r SAMPLE; do
            run_sample "$SAMPLE" &
            ((count++))
            if (( count % NUM_THREADS == 0 )); then
                wait
            fi
        done < "$SAMPLES_LIST"
        wait
        ;;
    *)
        echo "Invalid mode: $MODE"
        exit 1
        ;;
esac

# -----------------------
# Final JSON dump if needed
# -----------------------
if [[ "$MODE" != "per-sample-clean" ]]; then
    FINAL_OUTDIR="$OUTPUT_DIR/all_samples"
    mkdir -p "$FINAL_OUTDIR"
    singularity exec \
        --bind "$DATA_DIR/mongo_data:/data/db" \
        --bind "$FINAL_OUTDIR:/output" \
        "$MONGO_SIF" \
        mongoexport \
            --jsonArray \
            --uri "mongodb://root:example@127.0.0.1:27017/beacon?authSource=admin" \
            --collection genomicVariations \
            --out /output/genomicVariations.json
fi

# -----------------------
# Shutdown MongoDB
# -----------------------
singularity exec \
    --bind "$DATA_DIR/mongo_data:/data/db" \
    "$MONGO_SIF" \
    mongosh --host localhost --port 27017 --eval "db.getSiblingDB('admin').shutdownServer()"

wait $MONGO_PID

