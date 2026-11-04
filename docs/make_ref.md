# Build a VarsGT genotyping marker panel

`main.make_ref.sh` builds the files VarsGT reads from `--panel-dir`: SNP and INDEL sites, DELLY SV sites, and the Beagle reference panel. Giraffe graph files (`*.gbz`, `*.hapl`, `*.graph_prefix.txt`, `*.ref_order.txt`) and the Nipponbare FASTA stay in place.

The final marker VCF keeps marker IDs and genotypes, but `delly call -v` also needs the original DELLY site record. `DELLY_RAW_VCFS` supplies those records, including `END`, `SVTYPE`, `CT`, and the rest of the INFO field. The checked-in defaults build the Rice1171 `r2=0.02` panel into `Rice1171_VarsGT_Index`. Point `PANEL_DIR`, `TARGET_DIR`, `PREFIX`, and `EXPECTED_SAMPLES` at another panel, such as Rice655, to build that one instead.

## Key steps in the script

The script has no positional arguments. Paths and the sample-count check are environment variables. It then runs these steps:

1. Read `${PANEL_DIR}/${PREFIX}.final.snp.vcf.gz`, `${PREFIX}.final.indel.vcf.gz`, and `${PREFIX}.final.sv.vcf.gz`. Each VCF must contain `EXPECTED_SAMPLES` samples in the same sample order.
2. Check SNP and INDEL REF alleles with `bcftools norm -c e` against `REFERENCE_FASTA`. The check does not rewrite the supplied alleles.
3. Write a sites-only VCF and a `CHROM:POS-POS` interval file for SNPs and for INDELs.
4. Concatenate and coordinate-sort the three final VCFs into `${PREFIX}.ref_panel.vcf.gz` for Beagle. Every sample genotype is kept.
5. Match each final SV to exactly one raw DELLY record. Callsets whose label appears in that marker's `Cohort` column are tried first, in `DELLY_RAW_VCFS` order. The sites file is sites-only: sample columns are removed, and the ID is replaced with the final-panel marker ID.
6. After the checks pass, copy any existing panel files to `backup_<YYYYmmdd_HHMMSS>.<pid>/` and install the new files into `TARGET_DIR`. A failed run leaves the previous panel unchanged.

The variables that control this are at the top of `main.make_ref.sh`:

```bash
PANEL_DIR="${PANEL_DIR:-/data3/home/gulei/projects/GraphPan/Multi_Source_Marker_Panel_generation/1171rice.wg_ld_r2_scan/final_panels/r2_0.02}"
DELLY_RAW_VCFS="${DELLY_RAW_VCFS:-1171rice=<1171 DELLY VCF>,655rice=<655 DELLY VCF>}"
TARGET_DIR="${TARGET_DIR:-${SCRIPT_DIR}/Rice1171_VarsGT_Index}"
REFERENCE_FASTA="${REFERENCE_FASTA:-${TARGET_DIR}/Nip.chrnum.sorted.fa}"
PREFIX="${PREFIX:-1171rice}"
EXPECTED_SAMPLES="${EXPECTED_SAMPLES:-1171}"
KEEP_STAGE="${KEEP_STAGE:-false}"
CACHED_DELLY_CANDIDATES="${CACHED_DELLY_CANDIDATES:-}"
```

`DELLY_RAW_VCFS` is a comma-separated `LABEL=VCF` list. `LABEL` should match `Cohort` in `${PREFIX}.canonical_markers.tsv` when that table is present. The first entry also supplies the header of the sites-only SV file.

## Requirements

The following commands must be on `PATH`, or set to absolute paths with the variables in parentheses:

- `bcftools` (`BCFTOOLS`)
- `bgzip` (`BGZIP`)
- `tabix` (`TABIX`)
- `python3` (`PYTHON`)

`TARGET_DIR` must already exist and contain the reference FASTA used to check SNP and INDEL REF alleles. The default FASTA is `${TARGET_DIR}/Nip.chrnum.sorted.fa`.

## Inputs

`PANEL_DIR` must contain three VCFs named from `PREFIX`:

| File | Role |
| --- | --- |
| `${PREFIX}.final.snp.vcf.gz` | Final SNP markers and genotypes |
| `${PREFIX}.final.indel.vcf.gz` | Final INDEL markers and genotypes |
| `${PREFIX}.final.sv.vcf.gz` | Final SV markers and genotypes |

The three VCFs must each contain `EXPECTED_SAMPLES` samples, in the same sample order. SNP and INDEL REF alleles are checked with `bcftools norm -c e` against `REFERENCE_FASTA`. That check does not rewrite the supplied alleles.

`${PREFIX}.canonical_markers.tsv` is optional and is read from `PANEL_DIR`. When it is present, SV rows supply a cohort label that decides which raw DELLY callset is tried first. It is tab-separated, with a header, and the used columns are `Marker_ID`, `Variant_Type`, and `Cohort`. The Rice1171 final-panel directory does not contain this table; the build below links the copy from the `r2=0.02` run.

`DELLY_RAW_VCFS` is the original DELLY callset list. The final panel VCF keeps marker IDs and genotypes, but `delly call -v` also needs the DELLY site record: `END`, `SVTYPE`, `CT`, and the rest of the INFO field. Each entry is `LABEL=VCF`, separated by commas. `LABEL` should match `Cohort` when a canonical table is used. The first entry supplies the header of the sites-only SV file, and every callset is expected to come from the same DELLY workflow.

| Variable | Default |
| --- | --- |
| `PANEL_DIR` | `/data3/home/gulei/projects/GraphPan/Multi_Source_Marker_Panel_generation/1171rice.wg_ld_r2_scan/final_panels/r2_0.02` |
| `DELLY_RAW_VCFS` | `1171rice=<1171 DELLY VCF>,655rice=<655 DELLY VCF>` |
| `TARGET_DIR` | `<script directory>/Rice1171_VarsGT_Index` |
| `REFERENCE_FASTA` | `${TARGET_DIR}/Nip.chrnum.sorted.fa` |
| `PREFIX` | `1171rice` |
| `EXPECTED_SAMPLES` | `1171` |
| `KEEP_STAGE` | `false` |
| `STAGE_ROOT` | `${TARGET_DIR}/.rebuild_stage` |
| `CACHED_DELLY_CANDIDATES` | empty |

The two default DELLY paths are the 1171-rice callset and the 655-rice callset used while this panel was built. List the panel's own callset first.

## Build Rice1171_VarsGT_Index

This rebuilds the genotyping panel inside the existing Rice1171 index. The directory already holds the Giraffe graph and the Nipponbare FASTA. Those files stay in place:

- `Nip_42_rice.gbz`
- `Nip_42_rice.hapl`
- `1171rice_graph_prefix.txt`
- `Nip.ref_order.txt`
- `Nip.chrnum.sorted.fa`

The final marker panel is the `r2=0.02` release. It contains `1171rice.final.snp.vcf.gz`, `1171rice.final.indel.vcf.gz`, and `1171rice.final.sv.vcf.gz`, each with 1,171 samples:

```text
/data3/home/gulei/projects/GraphPan/Multi_Source_Marker_Panel_generation/1171rice.wg_ld_r2_scan/final_panels/r2_0.02
```

SV INFO comes from two raw DELLY callsets. `1171rice` is searched first. `655rice` covers panel SVs that were called in the 655-rice cohort. The 1171 callset has no `.tbi` or `.csi` index, so the script streams it and keeps only the panel loci.

| Label | Raw DELLY VCF |
| --- | --- |
| `1171rice` | `/data3/home/gulei/projects/GraphPan/GATK-DELLY-VariantsCalling/1171_sv_run/1171rice/delly_no_germline/0.5_0.05.filtered.merged.genotype.id.samples_sort.biallelic.vcf.gz` |
| `655rice` | `/data3/home/gulei/projects/GraphPan/GATK-DELLY-VariantsCalling/705rice_graph/delly_no_germline/0.5_0.05.filtered.merged.genotype.id.samples_sort.biallelic.rename.dedup_samples.vcf.gz` |

The cohort table for this threshold is next to the run output, not in `final_panels`. Its SV rows are 31,969 `1171rice` and 87 `655rice`. Link it into the panel directory before the rebuild so those 87 markers try the 655-rice callset first:

```sh
ln -sfn \
  /data3/home/gulei/projects/GraphPan/Multi_Source_Marker_Panel_generation/1171rice.wg_ld_r2_scan/runs/r2_0.02/panel_output/marker_panel/1171rice.canonical_markers.tsv \
  /data3/home/gulei/projects/GraphPan/Multi_Source_Marker_Panel_generation/1171rice.wg_ld_r2_scan/final_panels/r2_0.02/1171rice.canonical_markers.tsv
```

From the VarsGT directory, the default variable values already point at this panel and at `Rice1171_VarsGT_Index`:

```sh
cd ~/projects/Aquila-GS/breeding_application/VarsGT
bash main.make_ref.sh
```

The same rebuild with every path written out:

```sh
cd ~/projects/Aquila-GS/breeding_application/VarsGT

PANEL_DIR=/data3/home/gulei/projects/GraphPan/Multi_Source_Marker_Panel_generation/1171rice.wg_ld_r2_scan/final_panels/r2_0.02 \
DELLY_RAW_VCFS="1171rice=/data3/home/gulei/projects/GraphPan/GATK-DELLY-VariantsCalling/1171_sv_run/1171rice/delly_no_germline/0.5_0.05.filtered.merged.genotype.id.samples_sort.biallelic.vcf.gz,655rice=/data3/home/gulei/projects/GraphPan/GATK-DELLY-VariantsCalling/705rice_graph/delly_no_germline/0.5_0.05.filtered.merged.genotype.id.samples_sort.biallelic.rename.dedup_samples.vcf.gz" \
TARGET_DIR="${PWD}/Rice1171_VarsGT_Index" \
REFERENCE_FASTA="${PWD}/Rice1171_VarsGT_Index/Nip.chrnum.sorted.fa" \
PREFIX=1171rice \
EXPECTED_SAMPLES=1171 \
bash main.make_ref.sh
```

A successful run replaces these panel files in `Rice1171_VarsGT_Index`. Previous copies are saved under `backup_<YYYYmmdd_HHMMSS>.<pid>/` first:

- `1171rice.snp.sites.vcf`
- `1171rice.snp.markers.intervals`
- `1171rice.indel.sites.vcf`
- `1171rice.indel.markers.intervals`
- `1171rice.delly.sv.sites.bcf` and `1171rice.delly.sv.sites.bcf.csi`
- `1171rice.ref_panel.vcf.gz` and `1171rice.ref_panel.vcf.gz.tbi`
- `1171rice.ref_index.build_summary.tsv`

`1171rice_0.02.full.all.impute.vcf.gz` is left unchanged. VarsGT reads `1171rice.ref_panel.vcf.gz` as the Beagle panel. Point `--panel-dir` at `Rice1171_VarsGT_Index` after the rebuild. When the graph and the panel stay in this same directory, `--index-dir` can be that path and `--panel-dir` can be omitted.

## Run another panel

Rice655 uses the same script. Put `655rice` before `1171rice` so a marker tagged with both cohorts keeps the previous search order:

```sh
PANEL_DIR=/data3/home/gulei/projects/GraphPan/Multi_Source_Marker_Panel_generation/655rice.wg_ld_r2_scan/final_panels/r2_0.035 \
DELLY_RAW_VCFS="655rice=/path/to/655rice.delly.vcf.gz,1171rice=/path/to/1171rice.delly.vcf.gz" \
TARGET_DIR="${PWD}/Rice655_VarsGT_Index" \
PREFIX=655rice \
EXPECTED_SAMPLES=655 \
bash main.make_ref.sh
```

Set `KEEP_STAGE=true` to keep the temporary build directory after a successful run. A failed run always keeps it.

An indexed raw VCF is subset with `bcftools view -T`. A VCF without `.tbi` or `.csi` is streamed once and filtered to the panel loci. To skip a repeated scan, pass site-only candidate VCFs with the same labels:

```sh
CACHED_DELLY_CANDIDATES="1171rice=/path/to/delly_1171.candidates.vcf,655rice=/path/to/delly_655.candidates.vcf" \
bash main.make_ref.sh
```

Each cache file is the uncompressed VCF produced by `bcftools view -G -T <target intervals> -Ov`.

## What the script writes

Files are built under `${STAGE_ROOT}/<YYYYmmdd_HHMMSS>.<pid>/build`, checked, and then installed into `TARGET_DIR`. `main.nf` discovers panel files by filename in the top level of `--panel-dir`, so each installed name must match exactly one discovery pattern.

| Installed file | Used by VarsGT for |
| --- | --- |
| `${PREFIX}.snp.sites.vcf` | GATK HaplotypeCaller SNP alleles |
| `${PREFIX}.snp.markers.intervals` | SNP intervals, one `CHROM:POS-POS` line per site |
| `${PREFIX}.indel.sites.vcf` | GATK HaplotypeCaller INDEL alleles |
| `${PREFIX}.indel.markers.intervals` | INDEL intervals |
| `${PREFIX}.delly.sv.sites.bcf` and `.csi` | `delly call -v` site list |
| `${PREFIX}.ref_panel.vcf.gz` and `.tbi` | Beagle reference panel |
| `${PREFIX}.ref_index.build_summary.tsv` | Record counts, sample count, source panel, DELLY list, and backup path |

The reference panel is the three final VCFs concatenated and coordinate-sorted. It keeps every sample genotype. The DELLY sites file is sites-only: sample columns are removed, and the ID is replaced with the final-panel marker ID.

Before installation, any existing copies of the panel files above are copied to:

```text
${TARGET_DIR}/backup_<YYYYmmdd_HHMMSS>.<pid>/
```

Installation happens only after the checks below pass, so a failed run leaves the previous panel files unchanged.

To put the previous panel back, copy that backup directory onto `TARGET_DIR`. The `backup_dir` row in `${PREFIX}.ref_index.build_summary.tsv` is the directory written by that successful build:

```sh
BACKUP="$(awk -F '\t' '$1=="backup_dir"{print $2}' \
  "${TARGET_DIR}/${PREFIX}.ref_index.build_summary.tsv")"
cp -a "${BACKUP}/." "${TARGET_DIR}/"
```

The summary file itself is written only after a successful install and is not included in the backup. Restoring the panel files does not require it.

## Checks

The script stops if any of these fail:

- A required command or input file is missing or empty.
- `DELLY_RAW_VCFS` is empty, a label is duplicated, or an entry is not `LABEL=VCF`.
- SNP, INDEL, and SV sample counts differ from `EXPECTED_SAMPLES`, or their sample orders differ.
- SNP or INDEL REF alleles fail `bcftools norm -c e`.
- A sites VCF or interval file has a different record count from its source VCF.
- The combined reference panel has a different record count, sample count, sample order, or `CHROM/POS/ID/REF/ALT` identity from the three final VCFs.
- Any final SV cannot be matched to exactly one DELLY record, or the chosen record lacks `END`, `SVTYPE`, or `CT`.
- `CHROM/POS/ID` identities differ between the final SV VCF and the DELLY sites file.
- The build directory does not contain exactly one discoverable file for each panel resource.

For each SV, a candidate must share the locus, overlap the marker ID after stripping a trailing `-END<number>`, and have the same SVTYPE when ALT is a symbolic allele. Callsets whose label appears in that marker's `Cohort` values are tried first, following `DELLY_RAW_VCFS` order; the other callsets follow in the same order. Tied candidates within one callset are ranked by exact `END`, then an exact normalized ID set, then an exact raw ID. `MISSING`, `AMBIGUOUS`, and `MISSING_INFO` are recorded in:

```text
${STAGE_ROOT}/<run id>/reports/sv_match_report.tsv
```

On failure the log prints that staging directory. Inspect `sv_match_report.tsv` and, when present, `sv_missing_required_info.tsv` or `*.duplicate_sites.tsv`.

## Use the rebuilt panel

Point VarsGT `--panel-dir` at `TARGET_DIR`. Keep `--index-dir` on the Giraffe graph directory so a finished mapping can be reused. When both directories are the same path, omit `--panel-dir`.

```sh
./varsgt \
  --fq-dir-glob "/data/reads/*.read{1,2}.fastq.gz" \
  --index-dir "/data/Nip_42_rice_Index" \
  --panel-dir "/data/Rice1171_VarsGT_Index" \
  --project Rice1171_task \
  --out-dir /results/Rice1171_task \
  -resume
```

`main.nf` enables SNP, INDEL, and SV genotyping from the files present in `--panel-dir`. It expects exactly one `*.ref_panel.vcf.gz`, and at most one SNP sites VCF, one INDEL sites VCF, and one SV sites file matching `*.sv.sites.bcf`, `*.delly.sv.sites.bcf`, or the corresponding VCF names. Leave the backup directory as a subdirectory; discovery lists only the top-level files.
