# <img src="VarsGT-logo.svg" alt="VarsGT-logo" width="200"/>

**VarsGT** (**Var**iants **G**eno**T**yping) is a workflow designed for generating high-quality VCF files from second-generation sequencing (NGS) reads. By integrating allele-based genotyping strategies, it enables accurate detection and representation of SNPs, INDELs, and structural variants (SVs), thereby providing a comprehensive variant landscape for genomic selection.

VarsGT is currently built upon marker panels derived from two rice populations, namely the inbred rice population (705 accessions) and the hybrid rice population (1,171 accessions).

## Dependencies
### [Nextflow](https://www.nextflow.io)
Make sure Java 17 or later is installed on your computer by using the command:
```sh
java -version
```
Enter this command in your terminal:
```sh
curl -s https://get.nextflow.io | bash
```
Make the binary executable and move it to a directory in your PATH.

### Java Softwares
```sh
git clone https://github.com/GooLey1025/VarsGT.git
cd VarsGT
wget -c -P softwares https://zenodo.org/records/19529002/files/picard.jar
wget -c -P softwares https://zenodo.org/records/19529002/files/GenomeAnalysisTK3.7.jar
wget -c -P softwares https://zenodo.org/records/19529002/files/beagle.27Feb25.75f.jar
```

### Additional software you need to download separately
By deafult, all software will be used from your environment variables (`$PATH`). You can edit the software path in `params.yaml`.
#### Java 8

**Important**: You need to download a specific version of java 8 and make sure it in your `$PATH`, as GATK 3.7 requires Java 8. VarsGT will search java 8. You also can set `gatk_java_path` in `params.yaml`.
#### [vg](https://github.com/vgteam/vg)
Version v1.71.0 has been tested.
```sh
wget -c https://github.com/vgteam/vg/releases/download/v1.71.0/vg
chmod +x vg
echo 'export PATH="$PATH:'$(pwd)'"' >> ~/.bashrc
```
#### [delly](https://github.com/dellytools/delly) (v1.7.2 has been tested)
#### [kmc](https://github.com/refresh-bio/KMC)
#### [bcftools](https://github.com/samtools/bcftools)
#### [samtools](https://github.com/samtools/samtools),[bgzip](https://github.com/DataBiosphere/bgzip),tabix
Easy to install:
```sh
conda install -c bioconda samtools
```

### (Required) Index files for graph pangenome-based genotyping.

For **Inbred line 705 rice accessions**
```sh
wget --content-disposition https://ndownloader.figshare.com/files/63989128
unzip 705rice_VarsGT_index.zip

```
For **Hybrid line 1171 rice accessions**
```sh
wget --content-disposition https://ndownloader.figshare.com/files/63989128
unzip 1171rice_VarsGT_index.zip
```

## "Quick" Test
This will read test data from `test_fq/` and output final relevant files in `test/`.
```sh
# First download test_fq file
wget -c -P test_fq https://zenodo.org/records/19626994/files/sample1.read1.fastq.gz
wget -c -P test_fq https://zenodo.org/records/19626994/files/sample1.read2.fastq.gz
# Demonstrating batch processing: VarsGT can handle all .fastq.gz files in a directory.
cp test_fq/sample1.read1.fastq.gz test_fq/sample2.read1.fastq.gz
cp test_fq/sample1.read2.fastq.gz test_fq/sample2.reads2.fastq.gz
# Quick Test
nextflow run main.nf -params-file test.params.yaml
```
The test will take about 15 minutes to run.


## Usage Case

### 1. Select task type

Choose the appropriate template configuration file based on your sample type (inbred line or hybrid line).  
If you plan to use the **Crossing Design** module in the RiceGPlex web platform, you must select the hybrid line configuration.

```bash
cp 705rice.template.params.yaml my.params.yaml
# or for hybrid lines:
cp 1171rice.template.params.yaml my.params.yaml
```
### 2. Configure parameters
Edit the configuration file:
```sh
vim my.params.yaml
```
Set the input FASTQ file pattern:
```sh
fq_dir_glob: "your_fq_dir_path/*.read{1,2}.fastq.gz"
```
Description:
- matches the sample identifier
- {1,2} specifies paired-end reads (read1 and read2)

```txt
Example:
test_fq/sample1.read1.fastq.gz
test_fq/sample1.read2.fastq.gz

test_fq/sample2.read1.fastq.gz
test_fq/sample2.read2.fastq.gz
```

The workflow will automatically detect all samples and their paired reads.
### 3. Set key parameters
```txt
project: "705rice_task"
out_dir: "705rice_task_out"

# Specify Java 8 executable path (required for GATK 3.7 UnifiedGenotyper)
gatk_java_path: "/path/to/java8/bin/java"
```

### 4. Run the workflow
```sh
nextflow run main.nf -params-file my.params.yaml -resume
```
