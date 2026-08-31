# PangenomiX CNV + SNV Pipeline

A production-oriented Bash workflow for **Axiom array data processing**, covering QC gating, CNV analysis, AxAS-compatible batch preparation, SNV Step2 genotyping, and base-call export.

> **Repository scope**
> This repository contains workflow code only. Thermo Fisher / Affymetrix APT binaries, Axiom library files, AxAS templates, CEL data, annotation databases, and other vendor or runtime assets are intentionally excluded.

---

## Overview

The pipeline processes Axiom array CEL files through sequential QC, CNV, and SNV analysis stages.

```text
CEL files
   │
   ▼
┌─────────────────────────────┐
│ 01. Build CEL list          │
└─────────────┬───────────────┘
              ▼
┌─────────────────────────────┐
│ 02. DishQC                  │
│ 03. Filter DishQC PASS      │
└─────────────┬───────────────┘
              ▼
┌─────────────────────────────┐
│ 04. Step1 genotyping        │
│     + call-rate QC          │
│ 05. Filter call-rate PASS   │
└─────────────┬───────────────┘
              │
       ┌──────┴──────┐
       ▼             ▼
   CNV workflow   SNV workflow
       │             │
       ▼             ▼
  06. CN summary  11. Step2 genotyping
  07. CNV HMM     12. Base-call export
  08. CNV export
  09. AxAS batch
  10. AxAS config
       │             │
       └──────┬──────┘
              ▼
        Final results
```

The master entry point is:

```bash
run_master.sh
```

---

## Pipeline stages

| Step | Stage               | Description                                        |
| ---: | ------------------- | -------------------------------------------------- |
|   01 | CEL discovery       | Build and validate the CEL file list               |
|   02 | DishQC              | Run array-level DishQC                             |
|   03 | DishQC filtering    | Retain DishQC PASS samples                         |
|   04 | Step1 genotyping    | Run initial genotyping and calculate call rate     |
|   05 | Call-rate filtering | Retain samples passing call-rate QC                |
|   06 | CN summarization    | Generate copy-number probeset summaries            |
|   07 | CNV Discovery       | Run Axiom CNV Discovery HMM                        |
|   08 | CNV export          | Generate final CNV result tables                   |
|   09 | AxAS packaging      | Prepare an AxAS-compatible CNV batch               |
|   10 | AxAS configuration  | Apply MAPD and related AxAS configuration files    |
|   11 | SNV Step2           | Run targeted Step2 genotyping                      |
|   12 | SNV export          | Export AxAS-style base calls and genotype matrices |

---

## Validated operating mode

The current strict production configuration requires:

```text
96 input CEL files
```

Samples failing QC may be excluded during downstream processing, so the final QC-PASS and SNV Step2 sample counts can be lower than 96.

The source workflow documented a historical SNV comparison against an AxAS reference export:

| Validation item         | Result |
| ----------------------- | -----: |
| AxAS samples            |     94 |
| Pipeline samples        |     94 |
| ProbeSets compared      |    209 |
| Genotype calls compared | 19,646 |
| Mismatches              |  **0** |

This repository preserves that result as **historical validation evidence**.

The vendor workflow is not independently reproduced within this repository because the required proprietary binaries, Axiom libraries, AxAS assets, and genomic test data are not distributed here.

---

## Requirements

| Component        | Requirement                                                              |
| ---------------- | ------------------------------------------------------------------------ |
| Operating system | Linux                                                                    |
| Shell            | Bash                                                                     |
| Python           | Python 3                                                                 |
| Core utilities   | `find`, `awk`, `grep`, `sort`, `sha256sum`, `tee`                        |
| APT              | Thermo Fisher / Affymetrix APT compatible with the validated environment |
| Array library    | PangenomiX Axiom library files                                           |
| AxAS assets      | Appropriate AxAS template/configuration files                            |
| SNV targets      | ProbeSet target list                                                     |

Required APT executables:

```text
apt-geno-qc-axiom
apt-genotype-axiom
apt-copynumber-axiom-hmm
apt-format-result
```

The current strict SNV workflow expects the Step1 calls metadata to report:

```text
APT version: v2.12.0-rc2
```

---

## Repository layout

The repository itself can be cloned anywhere. Vendor assets and runtime data should remain outside version control or inside ignored directories.

```text
pangenomix-cnv-snv-pipeline/
│
├── run_master.sh
├── 01_make_cel_list.sh
├── 02_run_dishqc.sh
├── ...
├── 12_export_snv_axas_style.sh
│
├── tools/
│   ├── check_repo.sh
│   └── ...
│
├── input/
│   └── axas_template_files/          # ignored / not distributed
│
├── Axiom_PangenomiX.r1/              # ignored / not distributed
│
├── snplists/
│   └── probe_pangenomix_acmg73_verified.txt
│
└── output/                            # ignored
```

Runtime assets may also be stored elsewhere and supplied through explicit environment variables or command-line arguments.

---

## Running the pipeline

### 1. Configure runtime dependencies

```bash
export LIB_DIR=/path/to/Axiom_PangenomiX.r1

export APT_DISHQC=/path/to/apt-geno-qc-axiom
export APT_GT=/path/to/apt-genotype-axiom
export APT_HMM=/path/to/apt-copynumber-axiom-hmm
export APT_FORMAT=/path/to/apt-format-result
```

### 2. Start a run

```bash
bash run_master.sh \
  /path/to/CEL_folder \
  RUN_NAME \
  /path/to/axas_template_files \
  /path/to/probeset_list.txt
```

Example:

```bash
bash run_master.sh \
  ./CEL \
  PangenomiX_20260831 \
  ./input/axas_template_files \
  ./snplists/probe_pangenomix_acmg73_verified.txt
```

---

## Optional controls

### Resume an interrupted run

Use resume mode only when restarting the **same analytical run with the same inputs and configuration**.

```bash
export RESUME=1
```

Then run `run_master.sh` normally.

### Strict SNV comparison against AxAS

An exported AxAS genotype result can be supplied for strict genotype-level comparison:

```bash
export SNV_REFERENCE_RESULT=/path/to/AxAS_export.txt
```

The validation step compares the pipeline SNV calls against the reference export and reports discordant calls.

---

## Main outputs

Run-specific outputs are written under:

```text
output/cnv_runs/<RUN_NAME>/
```

Key files include:

```text
output/cnv_runs/<RUN_NAME>/
│
├── 08_final_tables/
│
├── 11_snv_step2/
│   └── AxiomGT1.calls.txt
│
├── 12_snv_export/
│   ├── <RUN_NAME>_snv_axas_style.txt
│   └── <RUN_NAME>_snv_genotype_matrix.tsv
│
├── FINAL_RESULTS.tsv
└── run_master.console.log
```

### CNV

Final CNV tables are generated under:

```text
08_final_tables/
```

These files contain post-QC CNV Discovery results derived from the Axiom CNV HMM workflow.

### SNV

The SNV workflow generates both an AxAS-style export and a sample-by-ProbeSet genotype matrix:

```text
<RUN_NAME>_snv_axas_style.txt
<RUN_NAME>_snv_genotype_matrix.tsv
```

---

## Repository validation

Static repository checks can be executed with:

```bash
bash tools/check_repo.sh
```

The check validates Bash syntax, compiles embedded Python heredoc code, and verifies files against:

```text
SCRIPT_SHA256.txt
```

A lightweight GitHub Actions workflow performs the same static checks for pushes and pull requests.

The CI workflow intentionally does **not** execute the analytical pipeline because proprietary APT software, vendor libraries, templates, and genomic test data are not included in the repository.

---

## Data and repository safety

Raw genomic data and sample-level runtime outputs should never be committed to the repository.

The bundled `.gitignore` is configured to exclude common runtime and genomic file types, including CEL data, analytical outputs, APT logs, AxAS assets, and vendor library files.

Before every push, review the staging area:

```bash
git status
```

and, when necessary:

```bash
git diff --cached
```

Particular care should be taken to avoid committing files containing patient identifiers, sample identifiers, internal filesystem paths, proprietary annotation databases, vendor binaries, or licensed configuration assets.

---

## Reproducibility notes

This repository captures the workflow logic used for the validated PangenomiX CNV/SNV analysis environment.

Exact analytical reproduction additionally depends on external components that are not distributed here, including the matching Axiom library release, APT software version, AxAS configuration, annotation resources, and input CEL data.

Results generated with different versions of these dependencies should therefore be independently validated before production use.

---

## Intended use

This repository is intended for:

```text
workflow development
internal validation
pipeline maintenance
reproducibility documentation
bioinformatics engineering review
```

It is not intended to distribute Thermo Fisher / Affymetrix proprietary software or licensed genomic resources.

---

## License

No open-source license is currently included.

Before making this repository public or adding an open-source license, confirm ownership of the workflow code as well as any restrictions arising from employer intellectual-property policies, third-party software licenses, vendor assets, and internal work product.

---

## Disclaimer

This repository represents a bioinformatics workflow implementation and associated validation framework.

Any use in a clinical or diagnostic environment requires appropriate analytical validation, quality management, regulatory review, and verification within the intended laboratory environment.
