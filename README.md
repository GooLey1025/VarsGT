> **English** | [中文](README.cn.docker.md)
>
> **Docker install** | [Local install](README.manual.md) | [中国大陆-Docker install](README.cn.docker.md) | [中国大陆-Local install](README.cn.manual.md)

# VarsGT

**VarsGT** (**Var**iants **G**eno**T**yping) genotypes second-generation sequencing (NGS) reads against a predefined variant panel. Panels include the rice marker sets released with this repository and custom panels supplied by the user. Allele-based genotyping calls SNPs, INDELs, and structural variants (SVs) at sites in the selected panel and writes a standardized VCF for downstream analysis, particularly genomic selection on the [RiceGPlex website](https://www.xhhuanglab.cn/tool/ricegplex/#/datasets) we provide.

# Installation

## Docker image

```bash
docker pull goley04/varsgt:latest
```

The image entrypoint is Nextflow. Mount the working directory at `/data` and pass Nextflow arguments, including `run /opt/varsgt/main.nf`.

## Graph pangenome index

The graph index was built from 42 rice genomes and is about 1.5 GB. Download it into the directory you will mount into the container.

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

Run this from the VarsGT directory after the index download above. The test reads FASTQ files from `test_fq/` and writes results to `test_rice655-ref_out`. It genotypes the Rice655 panel and takes about 15 minutes.

```sh
wget https://zenodo.org/records/23924551/files/test_fq.zip?download=1 -O test_fq.zip
unzip test_fq.zip -d test_fq

docker run --rm \
  -v "${PWD}:/data" \
  -w /data \
  goley04/varsgt:latest \
  run /opt/varsgt/main.nf \
  --fq_dir_glob "test_fq/*.reads{1,2}.fastq.gz" \
  --index_dir Nip-42rice_GraphPangenome_Index \
  --panel_dir cohort_panel_index/rice655_index \
  --project test_rice655-ref \
  --out_dir test_rice655-ref_out \
  -work-dir work \
  -resume
```

# Usage

Paths inside `--fq_dir_glob`, `--index_dir`, `--panel_dir`, `--out_dir`, and `-work-dir` are resolved in the container. With `-v "${PWD}:/data"` and `-w /data`, a relative path is a path in the mounted directory.

```sh
docker run --rm \
  -v "${PWD}:/data" \
  -w /data \
  goley04/varsgt:latest \
  run /opt/varsgt/main.nf \
  --fq_dir_glob "/data/reads/*.read{1,2}.fastq.gz" \
  --index_dir /data/Nip-42rice_GraphPangenome_Index \
  --panel_dir /data/cohort_panel_index/rice655_index \
  --project rice655_task \
  --out_dir /data/results/rice655_task \
  -work-dir /data/work \
  -resume
```

`-resume` is Nextflow's native option. With no value it resumes the most recent compatible execution. A run name or session ID can also be given, for example `-resume last`, `-resume determined_borg`, or `-resume 4dc3bb0e-...`.

`--index_dir` is the Giraffe graph. It must contain `Nip_42_rice.gbz`, `Nip_42_rice.hapl`, `Nip.chrnum.sorted.fa`, exactly one `*.graph_prefix.txt`, and exactly one `*.ref_order.txt`. `--panel_dir` is the genotyping panel, such as `cohort_panel_index/rice655_index`. It must contain exactly one `*.ref_panel.vcf.gz`, plus the site files for the variant types to call: `*.snp.sites.vcf`, `*.indel.sites.vcf`, and at most one SV sites file (`*.sv.sites.bcf`, `*.delly.sv.sites.bcf`, or the matching VCF name). When `--panel_dir` is omitted, those panel files are read from `--index_dir`. Keep `--index_dir` on the same path so a finished Giraffe mapping can be reused.

Switch `--panel_dir` to `cohort_panel_index/rice3305_index` or `cohort_panel_index/rice1171_index` to genotype the other released panels against the same graph index.

## Build a genotyping panel

A genotyping panel is the directory passed to `--panel_dir`. It holds the SNP, INDEL, and SV sites VarsGT calls, the marker intervals, and the Beagle reference VCF used to impute the final genotypes. The Giraffe graph and the Nipponbare FASTA stay in `--index_dir` and are not rebuilt with the panel.

Rice655, Rice3305, and Rice1171 panels are already in `cohort_panel_index/`. To build a panel from your own final marker VCFs, follow [Build a VarsGT genotyping marker panel](docs/make_ref.md).

Users who already have a whole-genome VCF can project it onto a released panel with [`vcf_filter_impute.nf`](README.VCF_FILTER_IMPUTE.md).
