> **International users · Manual installation.** Switch to [Docker](README.md) · [中国大陆 · Docker](README.cn.docker.md) · [中国大陆 · 手动安装](README.cn.manual.md)

# VarsGT

**VarsGT** (**Var**iants **G**eno**T**yping) genotypes second-generation sequencing (NGS) reads against a predefined variant panel. Panels include the rice marker sets released with this repository and custom panels supplied by the user. Allele-based genotyping calls SNPs, INDELs, and structural variants (SVs) at sites in the selected panel and writes a standardized VCF for downstream analysis, particularly genomic selection on the [RiceGPlex website](https://www.xhhuanglab.cn/tool/ricegplex/#/datasets) we provide.

# Installation

## Software

Install Java 17 or newer and check it:

```sh
java -version
```

Install Nextflow and put the binary on `PATH`:

```sh
curl -s https://get.nextflow.io | bash
```

From this directory, download the JAR files used by the workflow:

```sh
mkdir -p softwares
wget -c -P softwares https://zenodo.org/records/19529002/files/picard.jar
wget -c -P softwares https://zenodo.org/records/19529002/files/beagle.27Feb25.75f.jar
```

Install these tools and make sure each executable is on `PATH`:

- [vg](https://github.com/vgteam/vg) v1.71.0 or newer
- [delly](https://github.com/dellytools/delly) (v1.7.2 has been tested)
- [kmc](https://github.com/refresh-bio/KMC)
- [bcftools](https://github.com/samtools/bcftools)
- [samtools](https://github.com/samtools/samtools), `bgzip`, and `tabix`

Download GATK 4.6.2 separately. Pass its `gatk-package-4.6.2.0-local.jar` to `./varsgt` with `--gatk-path`.

## Graph pangenome index

The graph index was built from 42 rice genomes and is about 1.5 GB.

```sh
wget https://zenodo.org/records/23924551/files/Nip-42rice_GraphPangenome_Index.zip?download=1 -O Nip-42rice_GraphPangenome_Index.zip
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
wget https://zenodo.org/records/23924551/files/test_fq.zip?download=1 -O test_fq.zip
unzip test_fq.zip -d test_fq

./varsgt \
  --fq-dir-glob "test_fq/*.reads{1,2}.fastq.gz" \
  --index-dir Nip-42rice_GraphPangenome_Index \
  --panel-dir cohort_panel_index/rice655_index \
  --gatk-path /path/to/gatk-package-4.6.2.0-local.jar \
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
  --gatk-path /path/to/gatk-package-4.6.2.0-local.jar \
  --project rice655_task \
  --out-dir /results/rice655_task \
  -resume
```

`-resume` is Nextflow's native option. With no value it resumes the most recent compatible execution. A run name or session ID can also be given, for example `-resume last`, `-resume determined_borg`, or `-resume 4dc3bb0e-...`. `--resume` is still accepted.

`--index-dir` is the Giraffe graph. It must contain `Nip_42_rice.gbz`, `Nip_42_rice.hapl`, `Nip.chrnum.sorted.fa`, exactly one `*.graph_prefix.txt`, and exactly one `*.ref_order.txt`. `--panel-dir` is the genotyping panel, such as `cohort_panel_index/rice655_index`. It must contain exactly one `*.ref_panel.vcf.gz`, plus the site files for the variant types to call: `*.snp.sites.vcf`, `*.indel.sites.vcf`, and at most one SV sites file (`*.sv.sites.bcf`, `*.delly.sv.sites.bcf`, or the matching VCF name). When `--panel-dir` is omitted, those panel files are read from `--index-dir`. Keep `--index-dir` on the same path so a finished Giraffe mapping can be reused.

Switch `--panel-dir` to `cohort_panel_index/rice3305_index` or `cohort_panel_index/rice1171_index` to genotype the other released panels against the same graph index.

## Build a genotyping panel

A genotyping panel is the directory passed to `--panel-dir`. It holds the SNP, INDEL, and SV sites VarsGT calls, the marker intervals, and the Beagle reference VCF used to impute the final genotypes. The Giraffe graph and the Nipponbare FASTA stay in `--index-dir` and are not rebuilt with the panel.

Rice655, Rice3305, and Rice1171 panels are already in `cohort_panel_index/`. To build a panel from your own final marker VCFs, follow [Build a VarsGT genotyping marker panel](docs/make_ref.md).

Users who already have a whole-genome VCF can project it onto a released panel with [`vcf_filter_impute.nf`](README.VCF_FILTER_IMPUTE.md).
