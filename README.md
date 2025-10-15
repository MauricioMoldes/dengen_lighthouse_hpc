# dengen_lighthouse_hpc

# HPC-Lighthouse

HPC-Lighthouse is a solution for deploying the **Beacon v2 Production Implementation (PI)** in **offline or restricted HPC environments**.  
Many HPC systems do not allow Docker, root access, or external internet connectivity, which prevents running the standard Beacon v2 setup. HPC-Lighthouse solves this by providing **Singularity containerized versions** of the core components, enabling fully offline, reproducible deployments.

The project is designed for environments that need:

- Offline operation without internet access
- Rootless execution on HPC systems
- Full reproducibility and portability
- Easy deployment and testing

---

## Key Components

HPC-Lighthouse focuses on the essential elements required for Beacon v2 functionality:

1. **Database Container (`beacon2-db.sif`)** – The database service used by Beacon.
2. **Tools Container (`beacon2-tools.sif`)** – Tools for converting and loading VCF data into the database.

These containers can be built from the official [Beacon v2 PI repository](https://github.com/EGA-archive/beacon2-pi-api) and run on any HPC system that supports **Singularity** or **Apptainer**.

---

## Features

- Fully offline deployment of Beacon v2
- Rootless HPC compatibility
- Singularity-based containerization
- Automated build scripts for reproducibility
- Sample configuration and deployment scripts for quick startup

---

## Singularity Containerization

This section describes how **HPC-Lighthouse** uses **Singularity** to provide an offline-compatible deployment of the [Beacon v2 Production Implementation (PI)](https://github.com/EGA-archive/beacon2-pi-api).

While the official implementation is based on Docker, most **high-performance computing (HPC)** environments restrict internet and root access.  
To overcome these limitations, HPC-Lighthouse converts key Docker images into **Singularity (`.sif`) containers**, allowing fully offline execution.

### Overview

The conversion focuses on the two essential containers that form the core of the Beacon v2 workflow:

| Singularity Image | Original Component | Purpose |
|--------------------|--------------------|----------|
| `beacon2-db.sif` | `db` | Provides the Beacon database service. |
| `beacon2-tools.sif` | `beacon-ri-tools` | Provides tools for converting and loading VCF data into the database. |

Both containers are lightweight, reproducible, and can run in completely offline environments that support Singularity or Apptainer.

---

### Build Process

The build process is automated by the script:

```
singularity/build_reference.sh
```

This script performs the following steps:

1. Checks for the presence of `docker` and `singularity`.
2. Clones or updates the official **Beacon v2 PI** repository.
3. Builds the two relevant Docker images:
   - `db`
   - `beacon-ri-tools`
4. Converts the resulting Docker images into Singularity `.sif` images.
5. Tests the resulting containers to confirm successful conversion.

---

### Build Instructions

To build the Singularity images, run:

```bash
cd singularity  
bash build_reference.sh
```

After completion, two files will be generated:

```
beacon2-db.sif  
beacon2-tools.sif
```

These can be transferred directly to an offline HPC environment.

---

### Testing the Containers

You can verify the containers by running:

```bash
singularity exec beacon2-db.sif bash -c "echo DB container OK"
singularity exec beacon2-tools.sif bash -c "beacon2-ri-tools --help"
```

This confirms that both images were built and are executable.

---

### Transferring to an Offline HPC

Once the `.sif` files have been built on an online development system, copy them to the target HPC environment:

```bash
scp beacon2-*.sif user@hpc:/path/to/HPC-Lighthouse/singularity/
```

No internet or root privileges are required for execution.

---

## Project Structure

```
dengen_lighthouse_hpc/
├── config/                 # Configuration files
│   ├── chr_name_conv.txt   # Chromosome name conversion
│   └── hosts.txt           # Hosts file for beacon-tools
├── data/
│   ├── vcfs/               # Input annotated VCF files
│   ├── mongo_data/         # Persistent MongoDB data
│   ├── tmp/                # Temporary files during processing
│   ├── output/             # JSON exports from Beacon
│   └── dengen_anonymous_list_samples.txt  # Sample IDs to process
├── deployment/             # Scripts for deployment, singularity builds
├── docs/                   # Additional documentation
├── pipeline/
│   ├── beacon_wrapper.sh   # HPC wrapper to run Beacon workflow
│   └── beacon_pipeline.sh  # Pipeline to prepare VCF files
├── singularity/
│   ├── build_reference.sh  # Script to build SIF images
│   ├── beacon2-db.sif      # MongoDB container
│   └── beacon2-tools.sif   # Beacon tools container
├── tests/                  # Unit and integration tests
└── README.md
```

---

## Preparing the Sample List

Create `data/dengen_anonymous_list_samples.txt` with one sample ID per line:

```
sample_001
sample_002
sample_003
```

The pipeline will automatically locate the corresponding VCF files in `data/vcfs/` named as:

```
<sample>_annotated.vcf.gz
```

---

## Running the HPC Wrapper

The main entrypoint is `pipeline/beacon_wrapper.sh`. It supports three modes:

### 1. Sequential

Processes samples one by one and performs a final JSON export:

```bash
bash pipeline/beacon_wrapper.sh sequential
```

### 2. Per-Sample Clean

Processes each sample individually, exporting its JSON and cleaning the database before the next sample:

```bash
bash pipeline/beacon_wrapper.sh per-sample-clean
```

### 3. Parallel Batch

Processes multiple samples concurrently:

```bash
bash pipeline/beacon_wrapper.sh parallel-batch [NUM_THREADS]
```

- `NUM_THREADS` is optional (default is 10).

---

## Output

- JSON exports are stored in `data/output/`.  
- For `per-sample-clean`, each sample has its own folder:

```
data/output/sample_001/genomicVariations.json
```

- For sequential or parallel-batch, a combined export is stored in:

```
data/output/all_samples/genomicVariations.json
```

---

## Notes

- Temporary files are stored in `data/tmp/` and removed automatically.  
- MongoDB is started and stopped automatically using the Singularity container.  
- The pipeline is path-agnostic and works in any HPC environment with Singularity.  
- Ensure that `config/chr_name_conv.txt` and `config/hosts.txt` are present before running the wrapper.

---

## License

This project is open-source and available under the MIT License.

