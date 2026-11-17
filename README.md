> **English** | [中文](README.cn.docker.md)
>
> **Docker install** | [Local install](README.manual.md) | [中国大陆-Docker install](README.cn.docker.md) | [中国大陆-Local install](README.cn.manual.md)

# VarsGT

**VarsGT** (**Var**iants **G**eno**T**yping) genotypes second-generation sequencing (NGS) reads against a predefined variant panel. Panels include the rice marker sets released with this repository and custom panels supplied by the user. Allele-based genotyping calls SNPs, INDELs, and structural variants (SVs) at sites in the selected panel and writes a standardized VCF for downstream analysis, particularly genomic selection models on the [RiceGPlex website](https://www.xhhuanglab.cn/tool/ricegplex/#/datasets) we provide.

# Installation

The workflow and the three cohort panels are already in the image. A Docker install does not need a clone of this repository. Create a working directory and run the commands below from there.

```sh
mkdir -p varsgt-work
cd varsgt-work
```

## Docker image

```bash
docker pull goley04/varsgt:latest
```

## Graph pangenome index

The graph index was built from 42 rice genomes and is about 1.5 GB. Download it into the directory you will mount into the container.

```sh
wget 'https://zenodo.org/records/23942908/files/Nip-42rice_GraphPangenome_Index.zip?download=1' -O Nip-42rice_GraphPangenome_Index.zip
unzip Nip-42rice_GraphPangenome_Index.zip -d Nip-42rice_GraphPangenome_Index
```

## Rice cohort marker panels

This section is a simplified account of how the released panels were prepared. Building a panel involves many steps and details, including a cohort GWAS and a separate GWAS within each cross-validation fold, and those steps cannot be explained in full here. The concrete workflow is released in [Multi-Source Marker Panel generation](https://github.com/GooLey1025/Multi_Source_Marker_Panel_generation). We recommend that you prepare the marker panel for your own population from your own understanding of that population. The aim is the marker panel and the intervals for that population. The notes below only describe the ideas behind the panels we prepared. A more concise description is in the Methods section of the paper.

For the panels we released, sites are drawn from several sources and then written out as one marker panel plus the intervals used to genotype it:

- **Target-cohort GWAS and genome-wide LD.** The workflow re-runs GWAS on the target cohort, including a separate GWAS within each cross-validation fold, and keeps those association leads together with a genome-wide LD marker set.
- **RiceNavi QTN.** Previously reported quantitative trait nucleotides, kept so the panel can support QTN breeding recommendations.
- **Other-cohort GWAS leads.** These site files are assumed to be already extracted. If you do not have them, obtain them before you use this workflow. The panels we released use leads from seven cohorts (404rice, 1439rice, 176rice, 378rice, 3023rice, 532rice, and 1171rice). The first six contribute SNPs. 1171rice also contributes INDELs and SVs. Sites that cannot be genotyped safely on the target cohort, including sites missing from the source VCF, sites that are not biallelic, and sites with `ALT=*`, are left out.
- **Public GWAS, in two branches.** Each entry supplies genomic intervals, and an alleles file is optional. When alleles are absent, REF and ALT are discovered inside those intervals. Lead variants enter the marker set directly. Signal variants are genotyped on the target reads, restricted to biallelic sites, filtered by minor-allele frequency and call rate, imputed, and LD-pruned. Only the pruned signal sites are kept.
- **SV re-genotyping.** SV sites are taken from whole-genome Delly VCFs, merged, and called again on each target BAM. The panel therefore carries SV genotypes from the target reads.
- **One site, one source.** When several sources nominate the same site, the panel keeps a single source in this order: RiceNavi QTN, current-cohort GWAS LD, public GWAS lead, public GWAS signal after LD pruning, other-cohort GWAS LD, then genome-wide LD. Audit tables still list every source and every trait.

A production run builds one panel for the full cohort. The cross-validation run builds one panel per training fold, with GWAS fit only on the training samples of that fold. SNP, INDEL, and SV sites are genotyped on the target sequencing data and imputed to produce the final panel.

Three cohort panels are provided. Choose the panel that matches the material you are genotyping. The panel files are in the image at `/opt/varsgt/cohort_panel_index/`.

- **Rice655.** Inbred panel. The marker set is an MSMP (Multi-Source Marker Panel): trait-associated lead variants, genome-wide lead variants, GWAS lead variants, and RiceNavi QTN variants. It supports QTN breeding recommendations and is intended for homozygous inbred materials.

- **Rice3305.** Large inbred panel. The marker set contains genome-wide lead variants only. It does not include QTN markers, so breeding recommendations are not available. This cohort has large-scale phenotype data from multiple populations and multiple environments.

- **Rice1171.** Hybrid panel for hybrid rice breeding. It uses the same MSMP as Rice655.

Traits that the released [Aquila genomic selection models](https://github.com/GooLey1025/Aquila-GS) can predict for these panels are listed on the [Datasets page of RiceGPlex website](https://www.xhhuanglab.cn/tool/ricegplex/#/datasets).

# Quick test

Run this from that working directory after the index download above. The test reads FASTQ files from `test_fq/` and writes results to `test_rice655-ref_out`. It genotypes the Rice655 panel and takes about 15 minutes.

```sh
wget 'https://zenodo.org/records/24048207/files/test_fq.zip?download=1' -O test_fq.zip
unzip test_fq.zip -d test_fq

docker run --rm \
  -v "${PWD}:/data" \
  -w /data \
  goley04/varsgt:latest \
  run /opt/varsgt/main.nf \
  --fq_dir_glob "test_fq/*.reads{1,2}.fastq.gz" \
  --index_dir Nip-42rice_GraphPangenome_Index \
  --panel_dir /opt/varsgt/cohort_panel_index/rice655_index \
  --project test_rice655-ref \
  --out_dir test_rice655-ref_out \
  -work-dir work \
  -resume test_cache
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
  --panel_dir /opt/varsgt/cohort_panel_index/rice655_index \
  --project rice655_task \
  --out_dir /data/results/rice655_task \
  -work-dir /data/work \
  -resume rice655_cache
```

- `--fq_dir_glob` is the paired FASTQ glob, for example `/data/reads/*.read{1,2}.fastq.gz`.
- `--index_dir` is the Giraffe graph. It must contain `Nip_42_rice.gbz`, `Nip_42_rice.hapl`, `Nip.chrnum.sorted.fa`, exactly one `*.graph_prefix.txt`, and exactly one `*.ref_order.txt`.
- `--panel_dir` is the genotyping panel. The image includes `/opt/varsgt/cohort_panel_index/rice655_index`. It must contain exactly one `*.ref_panel.vcf.gz`, the SNP and INDEL site files (`*.snp.sites.vcf`, `*.indel.sites.vcf`), and `*.delly.sv.sites.bcf`.
- `--project` is the project name written into the output.
- `--out_dir` is the directory for the final files.
- `-work-dir` is the Nextflow work directory.
- `-resume` resumes a previous Nextflow run. Give it the same cache name, such as `-resume rice655_cache`, to reuse that run. A run name or session ID also works, for example `-resume last` or `-resume 4dc3bb0e-...`. This is also how an interrupted run is continued.

For the same reads, change only `--panel_dir` to `/opt/varsgt/cohort_panel_index/rice3305_index` or `/opt/varsgt/cohort_panel_index/rice1171_index`, and pass `-resume` with the same mapping cache. The workflow then genotypes that panel directly and does not map the reads again.

## Server resources

The defaults below match a large server. Pass the same flags on the `docker run` command to fit a smaller or larger machine. Lower the CPU, memory, and parallel-task values when the server has less capacity. Raise them when more CPUs and memory are free. Quote memory values that contain a space, for example `--kmc_memory_per_task "16 GB"`.

- `--kmc_max_parallel_number` is the maximum number of KMC tasks at once. Default: `10`.
- `--kmc_cpus_per_task` is the number of CPUs for each KMC task. Default: `14`.
- `--kmc_memory_per_task` is the memory for each KMC task. Default: `28 GB`.
- `--bam_per_task_threads` is the number of CPUs for each BAM task. Default: `4`.
- `--bam_per_task_memory` is the memory for each BAM task. Default: `8 GB`.
- `--bam_max_parallel_num` is the maximum number of BAM tasks at once. Default: `4`.
- `--mark_duplicates` marks duplicate reads in the BAM. Default: `true`.
- `--giraffe_mapping_cpus_per_task` is the number of CPUs for each Giraffe mapping task. Default: `20`.
- `--giraffe_mapping_memory_per_task` is the memory for each Giraffe mapping task. Default: `30 GB`.
- `--giraffe_mapping_parallel_number` is the maximum number of Giraffe mapping tasks at once. Default: `4`.
- `--beagle_cpus` is the number of CPUs for Beagle imputation. Default: `32`.
- `--beagle_memory` is the memory for Beagle imputation. Default: `100 GB`.

## Build a genotyping panel

Rice655, Rice3305, and Rice1171 panels are already in the image at `/opt/varsgt/cohort_panel_index/`. To build a panel from your own final marker VCFs, follow [Build a VarsGT genotyping marker panel](docs/make_ref.md).
