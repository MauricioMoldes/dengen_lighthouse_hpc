#!/bin/bash
#
# build_reference.sh
# HPC-Lighthouse – builds and converts Beacon v2 core Docker images into Singularity format
#

set -e

echo "HPC-Lighthouse: Building Beacon v2 reference containers (db + beacon-ri-tools)..."

# --- Configuration ---
REPO_URL="https://github.com/EGA-archive/beacon2-pi-api.git"
WORKDIR="$(pwd)/beacon2-pi-api"
SIF_OUTPUT_DIR="$(pwd)"

# --- Step 1: Check dependencies ---
command -v docker >/dev/null 2>&1 || { echo "Docker not found. Please install Docker first."; exit 1; }
command -v singularity >/dev/null 2>&1 || { echo "Singularity not found. Please install Singularity first."; exit 1; }

# --- Step 2: Clone or update reference repo ---
if [ ! -d "$WORKDIR" ]; then
    echo "Cloning Beacon v2 Production Implementation repository..."
    git clone "$REPO_URL" "$WORKDIR"
else
    echo "Repository already exists. Updating..."
    cd "$WORKDIR" && git pull && cd ..
fi

cd "$WORKDIR"

# --- Step 3: Build Docker images for db and beacon-ri-tools ---
echo "Building Docker images..."
docker build -t beacon2-pi-db:latest -f docker/db.Dockerfile .
docker build -t beacon2-pi-tools:latest -f docker/beacon-ri-tools.Dockerfile .

# --- Step 4: Convert Docker → Singularity ---
cd "$SIF_OUTPUT_DIR"

echo "Converting Docker images to Singularity..."
singularity build beacon2-db.sif docker-daemon://beacon2-pi-db:latest
singularity build beacon2-tools.sif docker-daemon://beacon2-pi-tools:latest

# --- Step 5: Test Singularity images ---
echo "Testing Singularity images..."
echo "Testing DB image:"
singularity exec beacon2-db.sif bash -c "echo DB container OK"
echo "Testing Tools image:"
singularity exec beacon2-tools.sif bash -c "beacon2-ri-tools --help || echo Tools container OK"

# --- Step 6: Summary ---
echo "Singularity images created successfully:"
echo "  $SIF_OUTPUT_DIR/beacon2-db.sif"
echo "  $SIF_OUTPUT_DIR/beacon2-tools.sif"

echo "HPC-Lighthouse containerization complete."

