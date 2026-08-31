## PangenomiX CNV + SNV Pipeline

Production-oriented Bash pipeline for Axiom array data that performs QC gating, CNV analysis, AxAS-compatible CNV batch packaging, SNV Step2 genotyping, and base-call export.

Important: This repository contains workflow code only. Thermo Fisher/Affymetrix APT binaries, Axiom library files, AxAS template files, CEL data, annotation databases, and other vendor/runtime assets are not included and should not be committed.

# Pipeline

01  Build CEL list
02  DishQC
03  Filter DishQC PASS samples
04  Call rate / Step1 genotyping
05  Filter call-rate PASS samples
06  CN probeset summarization
07  CNV Discovery HMM
08  Export final CNV tables
09  Package AxAS Copy Number Discovery batch
10  Apply AxAS MAPD/configuration files
11  SNV Step2 genotyping
12  Export AxAS-style SNV base calls

The master entry point is run_master.sh.

# Validated operating mode

The current strict production mode requires exactly 96 input CEL files. Samples that fail QC may be removed downstream, so the final QC-PASS/Step2 sample count can be lower than 96.

The source package documented a historical SNV Golden comparison of:

94 AxAS samples vs. 94 pipeline samples

209 ProbeSets

19,646 genotype calls

0 mismatches

This GitHub package preserves that statement as historical validation evidence; it does not independently rerun the vendor workflow because vendor binaries, libraries, templates, and CEL data are not included here.

# Requirements

Linux / Bash

Python 3 (standard library only for the bundled scripts)

GNU/core command-line tools such as find, awk, grep, sort, sha256sum, tee

Affymetrix/Thermo Fisher APT executables compatible with the validated environment:

apt-geno-qc-axiom

apt-genotype-axiom

apt-copynumber-axiom-hmm

apt-format-result

PangenomiX Axiom library files

AxAS template files

ProbeSet target list

The SNV strict mode currently expects APT version string v2.12.0-rc2 in the Step1 calls metadata.

# Recommended runtime layout

The repository can be cloned anywhere. By default, output is created under the repository root. Vendor/runtime assets should live outside Git or in ignored folders.

repo/
├── run_master.sh
├── 01_make_cel_list.sh ... 12_export_snv_axas_style.sh
├── tools/
├── input/
│   └── axas_template_files/        # ignored / not distributed
├── Axiom_PangenomiX.r1/            # ignored / not distributed
├── snplists/
│   └── probe_pangenomix_acmg73_verified.txt
└── output/                          # ignored

You can also keep all runtime assets elsewhere and provide explicit paths.

# Run

export LIB_DIR=/path/to/Axiom_PangenomiX.r1
export APT_DISHQC=/path/to/apt-geno-qc-axiom
export APT_GT=/path/to/apt-genotype-axiom
export APT_HMM=/path/to/apt-copynumber-axiom-hmm
export APT_FORMAT=/path/to/apt-format-result

bash run_master.sh \
  /path/to/CEL_folder \
  RUN_NAME \
  /path/to/axas_template_files \
  /path/to/probeset_list.txt

Optional controls:

# Resume a previously interrupted run only when it is the same exact run.
export RESUME=1

# Strictly compare exported SNV calls against an AxAS reference export.
export SNV_REFERENCE_RESULT=/path/to/AxAS_export.txt

# Main outputs

output/cnv_runs/<RUN_NAME>/
├── 08_final_tables/
├── 11_snv_step2/AxiomGT1.calls.txt
├── 12_snv_export/<RUN_NAME>_snv_axas_style.txt
├── 12_snv_export/<RUN_NAME>_snv_genotype_matrix.tsv
├── FINAL_RESULTS.tsv
└── run_master.console.log

Static repository checks

bash tools/check_repo.sh

The check runs Bash syntax validation, compiles embedded Python heredocs, and verifies SCRIPT_SHA256.txt.

A lightweight GitHub Actions workflow runs the same static checks on pushes and pull requests. It does not run the analytical pipeline because vendor software and genomic test data are intentionally absent.

# Data and repository safety

Do not commit raw CEL files, sample-level outputs, APT logs, AxAS binary/template assets, annotation databases, or any files containing patient/sample identifiers. The bundled .gitignore blocks the most common runtime and genomic file types, but it is not a substitute for reviewing git status before every push.

For an employer-developed production workflow, confirm internal IP policy and third-party software/data licensing before making the repository public. A private repository is the safer default.

# License

No open-source license is included in this publication candidate. Add a license only after confirming ownership of the workflow code and the terms governing the related vendor assets and internal work product.
