**VarsGT** (**Var**iants **G**eno**T**yping) is a workflow designed for generating high-quality VCF files from second-generation sequencing (NGS) reads. By integrating allele-based genotyping strategies, it enables accurate detection and representation of SNPs, INDELs, and structural variants (SVs), thereby providing a comprehensive variant landscape for genomic selection.

VarsGT is currently built upon marker panels derived from two rice populations, namely the inbred rice population (705 accessions) and the hybrid rice population (1,171 accessions).

## Installation

### Recommended: use the VarsGT image

The image contains Nextflow, Java 17, a separate Java 8 runtime for GATK 3.7, and all command-line and Java-based workflow dependencies.

```bash
docker pull goley04/varsgt:latest
```

The image does not contain FASTQ data or the large rice index packages. The simplest approach is to run from a directory containing `reads/` and the downloaded index directory, and mount the current directory once:

```bash
docker run --rm \
  -v "${PWD}:/data" \
  -w /data \
  goley04/varsgt:latest \
  run /opt/varsgt/main.nf \
  --fq_dir_glob "/data/reads/*.read{1,2}.fastq.gz" \
  --index_dir /data/Nip_42_rice_Index \
  --panel_dir /data/Rice655_VarsGT_index \
  --project Rice655_task \
  --out_dir /data/Rice655_task_out \
  -work-dir /data/work \
  -resume
```

### Manual installation

Manual installation remains supported for systems where Docker is unavailable. It requires separate Java 17 and Java 8 runtimes plus the native bioinformatics tools. Follow the complete [manual installation guide](docs/INSTALL.md).

### Required index files for graph pangenome-based genotyping

For **Inbred line 705 rice accessions**

```sh
wget --content-disposition https://ndownloader.figshare.com/files/63989131
unzip Rice655_VarsGT_index.zip
```

For **Hybrid line 1171 rice accessions**

```sh
wget --content-disposition https://ndownloader.figshare.com/files/63989128
unzip Rice1171_VarsGT_index.zip
```



## Quick test

This will read test data from `test_fq/` and output final relevant files in `test/`.

```sh
# First download test_fq file
wget --content-disposition -P test_fq https://ndownloader.figshare.com//files/64029223
wget --content-disposition -P test_fq https://ndownloader.figshare.com//files/64029220
# Demonstrating batch processing: VarsGT can handle all .fastq.gz files in a directory.
cp test_fq/sample1.reads1.fastq.gz test_fq/sample2.reads1.fastq.gz
cp test_fq/sample1.reads2.fastq.gz test_fq/sample2.reads2.fastq.gz
# Quick Test
./varsgt \
  --fq-dir-glob "test_fq/*.reads{1,2}.fastq.gz" \
  --index-dir 705rice_VarsGT_index \
  --project test \
  --out-dir test
```

The test will take about 15 minutes to run.

## Usage Case



### CLI usage

The main entry point is:

```sh
./varsgt \
  --fq-dir-glob "/data/reads/*.read{1,2}.fastq.gz" \
  --index-dir "/data/Nip_42_rice_Index" \
  --panel-dir "/data/705rice_VarsGT_index" \
  --project 705rice_task \
  --out-dir /results/705rice_task \
  -resume
```

`-resume` follows Nextflow's native syntax. With no value it resumes the most
recent compatible execution. A Nextflow run name or session ID can also be
specified, for example `-resume last`, `-resume determined_borg`, or
`-resume 4dc3bb0e-...`. The older `--resume` spelling remains supported.

The index directory must contain exactly one `*.sv.sites.tsv`,
`*.sv.sites.vcf`, or `*.sv.sites.txt` file. VarsGT matches its columns 1, 2, 4,
and 5 as `CHROM`, `POS`, `REF`, and `ALT`; header and comment lines are ignored.
ALT must already be biallelic.

`--index-dir` is the Giraffe graph. It supplies `Nip_42_rice.gbz`,
`Nip_42_rice.hapl`, `Nip_42_rice.ref_order.txt`, `Nip_42_rice.graph_prefix.txt`,
and `Nip.chrnum.sorted.fa`. `--panel-dir` is the genotyping panel. It supplies
the SNP, INDEL, and SV site files, marker intervals, and `*.ref_panel.vcf.gz`.
When `--panel-dir` is omitted, both sets of files are read from `--index-dir`.
Keep `--index-dir` on the same path to reuse a finished Giraffe mapping.



## `vcf_filter_impute.nf`

This standalone workflow is **Path C** for rice users who already have a whole-genome VCF, whether it contains a population or only a few samples. It validates the input VCF, compares its variant sites with a downloaded VarsGT reference panel, optionally retains only sites that match the selected panel, and then runs Beagle to impute missing genotypes. After imputation, the workflow assigns each output record the corresponding marker ID from the selected reference panel using an exact `CHROM/POS/REF/ALT` match. The final output is a biallelic VCF containing the marker sites defined by the selected rice reference panel, with missing genotypes imputed and marker IDs populated from that panel.

### Input requirements

- The input VCF must be aligned to the Nipponbare reference genome.
- The `CHROM` column must contain only the numbers `1` through `12`. Values such as `chr1`, `Chr1`, or other chromosome prefixes are rejected.
- Input data are assumed to be biallelic by default. For a multiallelic VCF, add `--biallelic true`; the workflow will first run `bcftools norm -m -any`.
- The reference panel must be a compressed VCF supported by Beagle, such as the `705rice`, `3485rice`, or `1171rice` panel downloaded with the corresponding VarsGT index package.



### Match rate and filtering

Before Beagle imputation, the workflow compares unique sites using the complete `CHROM`, `POS`, `REF`, and `ALT` fields. The match rate is reported as:

```text
matched reference-panel sites / all unique reference-panel sites
```

The result is written to `<project>.match_report.tsv`. A rate below 80% is reported as `LOW_MATCH_RATE`; 80% is an empirical threshold from our experience and may not be appropriate for every population. A low rate means downstream phenotype prediction with a selected model may be inaccurate.

By default, the complete normalized input VCF is passed to Beagle. Add `--filter_first true` to pass only input records that exactly match sites in the selected reference panel. This option reduces the number of genotype records processed by Beagle and can substantially speed up imputation, especially for large whole-genome VCFs. However, removing non-matching input sites may reduce accuracy if those sites contain informative genotype signals. Use this option when faster processing is important, and interpret the results with caution when the match rate is low.

### Run

Install Nextflow, Java, `bcftools`, `bgzip`, and `tabix`, and provide the Beagle JAR from the VarsGT software package. The reference panel path is the panel in the index directory you downloaded for the population of interest:

```bash
nextflow run vcf_filter_impute.nf \
  --input_vcf /path/to/whole_genome.vcf.gz \
  --ref_impute_panel_vcf_path /path/to/705rice_VarsGT_index/705rice_0.03.full.all.impute.vcf.gz \
  --beagle_path ./softwares/beagle.27Feb25.75f.jar \
  --out_dir vcf_filter_impute_out \
  --project my_rice_samples \
  -resume
```

For multiallelic input and optional pre-filtering:

```bash
nextflow run vcf_filter_impute.nf \
  --input_vcf /path/to/whole_genome.multiallelic.vcf.gz \
  --ref_impute_panel_vcf_path /path/to/1171rice_VarsGT_index/1171rice_0.02.full.all.impute.vcf.gz \
  --beagle_path ./softwares/beagle.27Feb25.75f.jar \
  --biallelic true \
  --filter_first true \
  --out_dir vcf_filter_impute_out \
  -resume
```

The main outputs are `<project>.impute.biallelic.vcf.gz`, its tabix index, and the match-rate report. The final VCF is produced by a separate ID-annotation step that copies marker IDs from the selected reference panel based on exact `CHROM/POS/REF/ALT` matches. Use the imputed VCF as input to the platform's Trait Predictor.

### Important limitations and recommended use

Path C is intended as a practical, resource-saving option for breeders who already have a whole-genome VCF, especially when re-genotyping a large population from raw reads with VarsGT would require substantial computational resources. It projects the existing VCF onto a supplied rice panel and is therefore a convenient approximation, not a replacement for population-specific genotyping.

The selected panel and model may not fully represent your breeding population. Differences in population structure, plant materials, variant-calling methods, sequencing depth, and other technical factors can introduce genotype discrepancies and prediction bias. Consequently, a successful imputation and a high site match rate do not guarantee that the selected panel model is well calibrated for your population. The 80% match-rate threshold is an empirical warning threshold, not an accuracy guarantee.

For higher accuracy, we recommend training a model with your own population and phenotype data rather than relying only on a model trained on a provided reference population. When resources and raw reads are available, the most rigorous option is to run the complete VarsGT genotyping workflow from raw reads and then train or validate a population-specific model.
