> **English** | [中文](README.cn.manual.md)
>
> [Docker install](README.md) | **Local install** | [中国大陆-Docker install](README.cn.docker.md) | [中国大陆-Local install](README.cn.manual.md)

# VarsGT

**VarsGT** (**Var**iants **G**eno**T**yping) genotypes second-generation sequencing (NGS) reads against a predefined variant panel. Panels include the rice marker sets released with this repository and custom panels supplied by the user. Allele-based genotyping calls SNPs, INDELs, and structural variants (SVs) at sites in the selected panel and writes a standardized VCF for downstream analysis, particularly genomic selection models on the [RiceGPlex website](https://www.xhhuanglab.cn/tool/ricegplex/#/datasets) we provide.

# Installation

Clone the repository and enter it. The commands below are run from this directory.

```sh
git clone https://github.com/GooLey1025/VarsGT.git
cd VarsGT
```

## Software

Install Java 17 or newer and check it:

```sh
java -version
```

Install Nextflow and put the binary on `PATH`:

```sh
curl -s https://get.nextflow.io | bash
```

Picard and Beagle are already in `softwares/`.

Install these tools and make sure each executable is on `PATH`:

- [vg](https://github.com/vgteam/vg) v1.71.0
- [delly](https://github.com/dellytools/delly) (v1.7.2 has been tested)
- [kmc](https://github.com/refresh-bio/KMC)
- [bcftools](https://github.com/samtools/bcftools)
- [samtools](https://github.com/samtools/samtools), `bgzip`, and `tabix`

Download the GATK 4.6.2 jar. It is large and is not included in this repository:

```sh
mkdir -p software
wget 'https://zenodo.org/records/23942908/files/gatk-package-4.6.2.0-local.jar?download=1' -O software/gatk-package-4.6.2.0-local.jar
```

Pass that jar to `./varsgt` with `--gatk-path software/gatk-package-4.6.2.0-local.jar`.

## Graph pangenome index

The graph index was built from 42 rice genomes and is about 1.5 GB.

```sh
wget 'https://zenodo.org/records/23942908/files/Nip-42rice_GraphPangenome_Index.zip?download=1' -O Nip-42rice_GraphPangenome_Index.zip
unzip Nip-42rice_GraphPangenome_Index.zip -d Nip-42rice_GraphPangenome_Index
```

## Rice cohort marker panels

Three cohort panels are provided. Choose the panel that matches the material you are genotyping. The panel files are under `cohort_panel_index/`.

**Rice655.** Inbred panel. The marker set is an MSMP (Multi-Source Marker Panel): trait-associated lead variants, genome-wide lead variants, GWAS lead variants, and RiceNavi QTN variants. It supports QTN breeding recommendations and is intended for homozygous inbred materials.

**Rice3305.** Large inbred panel. The marker set contains genome-wide lead variants only. It does not include QTN markers, so breeding recommendations are not available. This cohort has large-scale phenotype data from multiple populations and multiple environments.

**Rice1171.** Hybrid panel for hybrid rice breeding. It uses the same MSMP as Rice655.

Traits that the released [Aquila genomic selection models](https://github.com/GooLey1025/Aquila-GS) can predict for these panels are listed on the [RiceGPlex website](https://www.xhhuanglab.cn/tool/ricegplex/#/datasets).

# Quick test

Run `./varsgt` from this directory. The test reads FASTQ files from `test_fq/` and writes results to `test_rice655-ref_out`. It genotypes the Rice655 panel and takes about 15 minutes.

```sh
wget 'https://zenodo.org/records/23942908/files/test_fq.zip?download=1' -O test_fq.zip
unzip test_fq.zip -d test_fq

./varsgt \
  --fq-dir-glob "test_fq/*.reads{1,2}.fastq.gz" \
  --index-dir Nip-42rice_GraphPangenome_Index \
  --panel-dir cohort_panel_index/rice655_index \
  --gatk-path software/gatk-package-4.6.2.0-local.jar \
  --project test_rice655-ref \
  --out-dir test_rice655-ref_out \
  -resume
```

# Usage

`./varsgt` accepts hyphenated options and forwards them to Nextflow.

```sh
./varsgt \
  --fq-dir-glob "/data/reads/*.read{1,2}.fastq.gz" \
  --index-dir "/data/Nip-42rice_GraphPangenome_Index" \
  --panel-dir "/data/cohort_panel_index/rice655_index" \
  --gatk-path software/gatk-package-4.6.2.0-local.jar \
  --project rice655_task \
  --out-dir /results/rice655_task \
  -resume
```

- `--fq-dir-glob` is the paired FASTQ glob, for example `/data/reads/*.read{1,2}.fastq.gz`.
- `--index-dir` is the Giraffe graph. It must contain `Nip_42_rice.gbz`, `Nip_42_rice.hapl`, `Nip.chrnum.sorted.fa`, exactly one `*.graph_prefix.txt`, and exactly one `*.ref_order.txt`.
- `--panel-dir` is the genotyping panel, such as `cohort_panel_index/rice655_index`. It must contain exactly one `*.ref_panel.vcf.gz`, the SNP and INDEL site files (`*.snp.sites.vcf`, `*.indel.sites.vcf`), and `*.delly.sv.sites.bcf`.
- `--gatk-path` is the GATK 4.6.2 jar, `gatk-package-4.6.2.0-local.jar`.
- `--project` is the project name written into the output.
- `--out-dir` is the directory for the final files.
- `-resume` resumes a previous Nextflow run. Give it the same cache name to reuse that run. A run name or session ID also works, for example `-resume last` or `-resume 4dc3bb0e-...`. `--resume` is still accepted. This is also how an interrupted run is continued.

For the same reads, change only `--panel-dir` to `cohort_panel_index/rice3305_index` or `cohort_panel_index/rice1171_index`, and pass `-resume` with the same mapping cache. The workflow then genotypes that panel directly and does not map the reads again.

## Build a genotyping panel

Rice655, Rice3305, and Rice1171 panels are already in `cohort_panel_index/`. To build a panel from your own final marker VCFs, follow [Build a VarsGT genotyping marker panel](docs/make_ref.md).
