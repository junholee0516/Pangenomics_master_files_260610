# Pangenomics_master_files_260610

PangenomiX Chip 기반 CNV 분석을 위한 테스트용 master files repository입니다.

본 repository는 `scripts/cnv_pipeline`을 중심으로 PangenomiX CNV 분석 script를 관리하고, APT 기반 command line 분석 환경을 정리하며, APT 결과를 기반으로 Axiom Analysis Suite 소프트웨어에 업로드 가능한 파일을 생성하기 위한 구조로 정리되어 있습니다.

작성 날짜: 2026.06.11
작성자: 이준호

---

## 1. Repository Structure

권장 폴더 구조는 아래와 같습니다.

```text
Pangenomics_master_files_260610/
├── Axiom_PangenomiX.r1/
├── apt_2.12.0_linux_64_x86_binaries.zip
├── apt_2.12.0_linux_64_x86_binaries/
├── scripts/
│   └── cnv_pipeline/
├── input/
│   └── axas_template_files/
│       ├── AxiomAnalysisSuiteData/
│       ├── CNData/
│       ├── Logs/
│       ├── QC/
│       ├── snpLists/
│       ├── Temp/
│       ├── AxiomGT1.calls.txt
│       ├── AxiomGT1.confidences.txt
│       ├── AxiomGT1.report.txt
│       ├── AxiomGT1.summary.a5
│       └── genotyping_cel_files
└── README.md
```

`apt_2.12.0_linux_64_x86_binaries.zip`은 다운로드한 APT 압축 파일입니다.
`apt_2.12.0_linux_64_x86_binaries/`는 압축 해제 후 생성되는 APT 실행 파일 폴더입니다.

---

## 2. Purpose

본 repository는 PangenomiX CNV 분석 환경을 정리하고, APT 기반 command line 분석 결과를 Axiom Analysis Suite 소프트웨어에서 활용할 수 있는 형태로 변환하기 위한 목적으로 사용됩니다.

주요 목적은 아래와 같습니다.

* PangenomiX CNV 분석 script 관리
* APT 기반 command line 분석 환경 정리
* APT 결과 기반 Axiom Analysis Suite 소프트웨어 업로드용 파일 생성

---

## 3. Required Software and Files

CNV pipeline 실행을 위해 아래 항목이 필요합니다.

```text
1. Axiom Analysis Suite
2. Axiom_PangenomiX.r1 library package
3. Analysis Power Tools
4. AxAS에서 RUN 중 또는 RUN 후 생성된 Output folder
5. Demo CEL file 또는 실제 CEL file
```

주의사항:

* CEL 파일은 Axiom Analysis Suite에서 분석할 때 사용합니다.
* CEL 파일 자체는 repository에 업로드하지 않는 것을 권장합니다.
* AxAS에서 RUN 중 또는 RUN 후 생성된 `Output` 폴더를 `input/axas_template_files/` 폴더로 복사하여 사용합니다.
* Public repository에 업로드할 경우 샘플명, 검체 정보, 내부 분석 결과 포함 여부를 반드시 확인해야 합니다.

---

## 4. Axiom Analysis Suite Download

Axiom Analysis Suite 소프트웨어는 아래 Thermo Fisher Scientific software download 페이지에서 다운로드합니다.

```text
https://www.thermofisher.com/kr/ko/home/technical-resources/software-downloads.html
```

다운로드 방법은 아래와 같습니다.

```text
1. 위 링크로 접속
2. Axiom Analysis Suite 5.0 클릭
3. Axiom Analysis Suite 5.4 항목 확인
4. Download now 클릭
5. Axiom Analysis Suite User Guide 안내에 따라 설치
```

Axiom Analysis Suite 5.4는 difficult marker 및 multiplate batch에서 genotyping 성능이 개선된 버전입니다.

또한 library package에 remote copy number genotyping 정보가 포함되어 있는 경우, AxAS Best Practices 및 Genotyping Analysis에서 remote copy number 관련 기능을 사용할 수 있습니다.

권장 사양은 아래와 같습니다.

```text
Operating system: Microsoft Windows 10 64-bit Professional
CPU: Quad Core 2.83 GHz 이상
RAM: 32 GB 권장
C drive free space: 최소 150 GB 이상 권장
```

주의사항:

```text
Axiom Analysis Suite는 Genome-Wide Human SNP Array 6.0 또는 legacy Affymetrix genotyping array 분석에는 사용할 수 없습니다.
```

---

## 5. Axiom_PangenomiX.r1 Library Package

PangenomiX Chip CNV 분석을 위해서는 `Axiom_PangenomiX.r1` library package가 필요합니다.

해당 library package는 Axiom Analysis Suite 설치 후 프로그램 내부에서 다운로드할 수 있습니다.

### Download Steps

```text
1. Axiom Analysis Suite 실행
2. Preferences 탭으로 이동
3. NetAffx Library/Annotations 항목 확인
4. 오른쪽에 있는 Update 클릭
5. Name 컬럼에서 Axiom_PangenomiX.r1 확인
6. Array Type 컬럼에서 Axiom_PangenomiX 확인
7. 해당 행의 Update? 체크박스 클릭
8. 체크 표시가 된 것을 확인한 후 OK 클릭
9. Library update 완료 후 아래 경로에서 Axiom_PangenomiX.r1 폴더 확인
```

Windows 기본 저장 위치:

```text
C:\Users\Public\Documents\AxiomAnalysisSuite\Library\Axiom_PangenomiX.r1
```

해당 폴더를 Linux 서버 또는 분석용 project directory로 복사합니다.

권장 위치:

```text
Pangenomics_master_files_260610/Axiom_PangenomiX.r1/
```

---

## 6. Analysis Power Tools Download

Analysis Power Tools는 APT 기반 command line 분석을 수행하기 위해 필요합니다.

APT는 GeneChip 및 Axiom array 분석 알고리즘을 command line 환경에서 실행할 수 있도록 제공되는 프로그램입니다.

다운로드 페이지:

```text
https://www.thermofisher.com/kr/ko/home/technical-resources/software-downloads.html
```

다운로드 방법은 아래와 같습니다.

```text
1. 위 링크로 접속
2. Axiom Analysis Suite 5.0 클릭
3. 페이지를 아래로 스크롤
4. Analysis Power Tools 섹션 확인
5. Learn more 클릭
6. 이동한 페이지에서 APT package 다운로드
```

다운로드할 파일:

```text
apt_2.12.0_linux_64_x86_binaries.zip
```

파일 정보:

```text
File name: apt_2.12.0_linux_64_x86_binaries.zip
File size: 200,411 KB
Checksum: 4da56954c7832b6855a4c8150f3a0913
```

Linux 서버에서 압축 해제합니다.

```bash
unzip apt_2.12.0_linux_64_x86_binaries.zip
```

권장 위치:

```text
Pangenomics_master_files_260610/apt_2.12.0_linux_64_x86_binaries/
```

---

## 7. Input Folder Preparation

`input/axas_template_files/` 폴더는 Axiom Analysis Suite에서 Demo CEL file 또는 실제 CEL file을 업로드하고 RUN을 실행하는 과정에서 생성되는 Output 파일을 복사하여 준비합니다.

AxAS에서 RUN 중 또는 RUN 후 결과는 기본적으로 아래 경로에 생성됩니다.

```text
C:\Users\Public\Documents\AxiomAnalysisSuite\Output
```

Demo CEL file 또는 실제 CEL file을 RUN 하면 아래와 같은 폴더가 생성됩니다.

```text
C:\Users\Public\Documents\AxiomAnalysisSuite\Output\<Demo_CEL_file_or_actual_CEL_file_name>
```

여기서 `<Demo_CEL_file_or_actual_CEL_file_name>`은 고정된 이름이 아닙니다.
Axiom Analysis Suite에서 사용한 Demo CEL file 또는 실제 CEL file 분석 이름에 따라 달라집니다.

해당 Output 폴더의 파일과 폴더를 아래 repository 위치로 복사합니다.

```text
Pangenomics_master_files_260610/input/axas_template_files/
```

최종 input 구조는 아래와 같습니다.

```text
Pangenomics_master_files_260610/
└── input/
    └── axas_template_files/
        ├── AxiomAnalysisSuiteData/
        ├── CNData/
        ├── Logs/
        ├── QC/
        ├── snpLists/
        ├── Temp/
        ├── AxiomGT1.calls.txt
        ├── AxiomGT1.confidences.txt
        ├── AxiomGT1.report.txt
        ├── AxiomGT1.summary.a5
        └── genotyping_cel_files
```

아래 4개 파일은 AxAS RUN 과정 중 생성되며, 분석이 완료되면 자동으로 삭제될 수 있습니다.

```text
AxiomGT1.calls.txt
AxiomGT1.confidences.txt
AxiomGT1.report.txt
AxiomGT1.summary.a5
```

따라서 해당 파일들은 RUN 과정 중 삭제되기 전에 미리 복사하여 `input/axas_template_files/` 폴더에 넣어야 합니다.

---

## 8. AxAS Output Folder Structure

아래는 Axiom Analysis Suite에서 RUN 후 생성되는 Output 폴더의 기본 구조입니다.

```text
C:\Users\Public\Documents\AxiomAnalysisSuite\Output\<Demo_CEL_file_or_actual_CEL_file_name>
├── AxiomAnalysisSuiteData/
├── CNData/
├── Logs/
├── QC/
├── snpLists/
├── Temp/
└── genotyping_cel_files
```

---

## 9. AxiomAnalysisSuiteData Folder

`AxiomAnalysisSuiteData` 폴더에는 AxAS 분석 설정 및 샘플 관련 정보가 포함됩니다.

```text
AxiomAnalysisSuiteData/
├── cel_headers
├── AnalysisConfiguration.threshold_settings
├── AnalysisConfiguration.analysis_settings
├── Configuration
├── sample_info.bin
├── batch_info
└── user_colors.bin
```

주의사항:

* `sample_info.bin`에는 샘플 정보가 포함될 수 있습니다.
* Public GitHub repository에 업로드할 경우 내부 샘플 정보 포함 여부를 반드시 확인해야 합니다.

---

## 10. CNData Folder

`CNData` 폴더에는 CNV 관련 결과 파일이 포함됩니다.

```text
CNData/
├── AxiomHMM.cnv.a5
└── AxiomHMM.report
```

주의사항:

```text
AxiomHMM.cnv.a5
```

위 파일은 용량이 매우 크고 분석 중 재생산될 수 있습니다.

따라서 repository에 input 예시 파일을 업로드한 후에는 아래 파일을 삭제해도 됩니다.

```text
Pangenomics_master_files_260610/input/axas_template_files/CNData/AxiomHMM.cnv.a5
```

삭제 후 남는 구조는 아래와 같습니다.

```text
Pangenomics_master_files_260610/input/axas_template_files/CNData/
└── AxiomHMM.report
```

---

## 11. Logs Folder

`Logs` 폴더에는 AxAS 및 APT 실행 로그가 포함됩니다.

```text
Logs/
├── CopynumberAPT2
├── GenotypingAPT2
├── ParamCheck
├── AxiomWorkflowLog
├── DebugAxiomWorkflow
├── CopynumberAPT2.errors
└── ParamCheck.errors
```

이 파일들은 분석이 정상적으로 수행되었는지 확인하거나 pipeline 오류 확인 시 참고할 수 있습니다.

현재 pipeline에서는 로그 파일이 AxAS와 다르게 생성될 수 있습니다.
다만 로그 파일의 차이는 Axiom Analysis Suite에서 결과를 확인하거나 분석하는 데 영향을 주지 않습니다.

---

## 12. QC Folder

`QC` 폴더는 생성되지만 비어 있을 수 있습니다.

```text
QC/
```

GitHub는 빈 폴더를 추적하지 않기 때문에 빈 폴더를 유지하려면 `.gitkeep` 파일을 추가할 수 있습니다.

```bash
touch input/axas_template_files/QC/.gitkeep
```

---

## 13. snpLists Folder

`snpLists` 폴더도 생성되지만 비어 있을 수 있습니다.

```text
snpLists/
```

GitHub에서 빈 폴더를 유지하려면 `.gitkeep` 파일을 추가할 수 있습니다.

```bash
touch input/axas_template_files/snpLists/.gitkeep
```

---

## 14. Temp Folder

`Temp` 폴더에는 AxAS 분석 과정에서 생성된 APT input 관련 임시 파일이 포함됩니다.

```text
Temp/
├── ChangedSCAxiom_PangenomiX.r1.apt-genotype-axiom.AxiomCN_GT1.apt2
├── Copynumber.APT2Input
└── GenoTyping.APT2Input
```

이 파일들은 AxAS에서 사용된 APT 실행 조건을 확인하는 데 참고할 수 있습니다.

---

## 15. CNV Pipeline Script

CNV pipeline 관련 script는 아래 경로에 위치합니다.

```text
scripts/cnv_pipeline/
```

실행 전 현재 경로와 파일 구성을 확인합니다.

```bash
cd /BiO/Pangenomics_master_files_260610
pwd
ls -lh
```

script 폴더를 확인합니다.

```bash
ls -lh scripts/cnv_pipeline
```

실행 권한을 부여합니다.

```bash
chmod +x scripts/cnv_pipeline/*.sh
```

---

## 16. Pipeline Execution

분석 실행 예시는 아래와 같습니다.

```bash
cd /BiO/Pangenomics_master_files_260610
bash scripts/cnv_pipeline/run_master.sh <CEL_DIR> <RUN_NAME> [TEMPLATE_FILES_DIR]
```

각 인자의 의미는 아래와 같습니다.

```text
<CEL_DIR>
    분석할 CEL 파일이 들어 있는 directory 경로입니다.

<RUN_NAME>
    결과 파일에 사용할 run 이름입니다.
    예: cnv_run_260611
    날짜를 마지막에 붙이는 형식을 권장합니다.

[TEMPLATE_FILES_DIR]
    input template file 위치입니다.
    현재 작업 위치가 Pangenomics_master_files_260610이고,
    input 파일이 기본 위치에 있다면 생략 가능합니다.
```

기본 input template file 위치는 아래와 같습니다.

```text
Pangenomics_master_files_260610/input/axas_template_files/
```

실행 전 아래 항목을 반드시 확인합니다.

```text
1. Axiom_PangenomiX.r1 폴더 위치
2. APT 실행 파일 위치
3. input/axas_template_files 폴더 위치
4. CEL 파일 위치
5. RUN_NAME 설정
```

---

## 17. GitHub Upload Notes

GitHub 업로드 전 아래 파일은 반드시 확인해야 합니다.

```text
input/axas_template_files/CNData/AxiomHMM.cnv.a5
```

`AxiomHMM.cnv.a5`는 용량이 매우 크기 때문에 GitHub 업로드에서 제외하거나 삭제하는 것을 권장합니다.

삭제 예시는 아래와 같습니다.

```bash
rm -f input/axas_template_files/CNData/AxiomHMM.cnv.a5
```

빈 폴더를 유지하려면 `.gitkeep` 파일을 추가합니다.

```bash
touch input/axas_template_files/QC/.gitkeep
touch input/axas_template_files/snpLists/.gitkeep
```

GitHub 업로드 예시는 아래와 같습니다.

```bash
git status

git add README.md
git add scripts/cnv_pipeline/
git add input/axas_template_files/

git commit -m "Add PangenomiX CNV pipeline files"
git push origin main
```

Public repository라면 아래 파일들은 업로드 전 반드시 확인해야 합니다.

```text
sample_info.bin
genotyping_cel_files
*.CEL
AxiomHMM.cnv.a5
회사 내부 기밀 자료
실제 샘플명 또는 개인정보가 포함된 파일
```

---

## 18. Notes

본 repository는 PangenomiX Chip CNV 분석 pipeline 정리 및 테스트를 위한 목적입니다.

Axiom Analysis Suite, APT, Axiom_PangenomiX.r1 library package는 Thermo Fisher Scientific에서 제공하는 소프트웨어 및 library package입니다.

해당 파일들은 사용 권한과 재배포 가능 여부를 확인한 후 사용해야 합니다.

---

## Author

Junho Lee
