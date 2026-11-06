#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

def checkVgVersion(vg_cmd) {
    def proc = ["bash", "-c", "${vg_cmd} version 2>&1"].execute()
    proc.waitFor()
    def output = proc.text.trim()
    def match = output =~ /(?i)(?:vg\s+version\s+)?v?(\d+)\.(\d+)\.(\d+)/

    if (proc.exitValue() != 0 || !match.find()) {
        error """
        [ERROR] Unable to determine vg version using: ${vg_cmd}

        ${output}

        Install vg v1.71.0 or pass:
          --vg-path /absolute/path/to/vg
        """
    }

    def major = match.group(1) as int
    def minor = match.group(2) as int
    if (major < 1 || (major == 1 && minor < 71)) {
        error """
        [ERROR] Incompatible vg version: ${output}

        The panel .hapl file uses Haplotypes format version 6.
        Use vg v1.71.0 or newer, for example:
          --vg-path /absolute/path/to/vg
        """
    }

    println "[INFO] vg version OK: ${output}"
}

params.fq_dir_glob = null
params.index_dir = null
params.panel_dir = null
params.gbz = null
params.out_dir = "output_dir"
params.ref_paths = null
params.validate_only = false

params.kmc_max_parallel_number = 10
params.kmc_cpus_per_task = 14
params.kmc_memory_per_task = "28 GB"
params.bam_per_task_threads = 4
params.bam_per_task_memory = "8 GB"
params.bam_max_parallel_num = 4
params.mark_duplicates = true
params.giraffe_mapping_memory_per_task = "30 GB"
params.giraffe_mapping_cpus_per_task = 20
params.giraffe_mapping_parallel_number = 4
params.beagle_memory = "100 GB"
params.beagle_cpus = 32

// GATK-DELLY genotyping parameters
params.project = "cohort"
params.ref = null
params.snp_site_vcf = null
params.indel_site_vcf = null
params.snp_markers_intervals = null
params.indel_markers_intervals = null
// Optional tool paths - if not specified, tools will be used from system PATH
params.java_path = null       // Java executable for GATK4, Picard, and Beagle.
params.delly_path = null
params.bcftools_path = null
params.samtools_path = null
params.tabix_path = null
params.python_path = null
params.ref_impute_panel_vcf_path = null
params.vg_path = null
params.bgzip_path = null
params.kmc_path = null
// Required software paths (JAR files)
params.gatk_path = baseDir.resolve("softwares/gatk-package-4.6.2.0-local.jar").toString()
params.picard_path = baseDir.resolve("softwares/picard.jar").toString()
params.beagle_path = baseDir.resolve("softwares/beagle.27Feb25.75f.jar").toString()

// Resource configuration (with defaults)
params.threads = 48
params.gatk_memory = '100g'
params.gatk_interval_padding = 100

// Fixed paths for repository utility scripts.
params.assign_id = file("${baseDir}/scripts/assign_id.sh", checkIfExists: true)
params.vcf_natural_sort = file("${baseDir}/scripts/vcf_natural_sort.sh")
params.convert_script = file("${baseDir}/scripts/convert-to-biallelic.py")

// Convert relative paths to absolute paths (if specified)
if (params.gatk_path) {
    params.gatk = file(params.gatk_path).toAbsolutePath()
} else {
    params.gatk = null
}
if (params.picard_path) {
    params.picard = file(params.picard_path).toAbsolutePath()
} else {
    params.picard = null
}

// GATK4 uses the same configurable Java executable as the other Java tools.
def configured_java = params.java_path?.toString()?.trim()
params.java = configured_java ? file(configured_java).toAbsolutePath().toString() : 'java'
params.delly = (params.delly_path && params.delly_path.toString().trim()) ? file(params.delly_path).toAbsolutePath().toString() : 'delly'
params.bcftools = (params.bcftools_path && params.bcftools_path.toString().trim()) ? file(params.bcftools_path).toAbsolutePath().toString() : 'bcftools'
params.samtools = (params.samtools_path && params.samtools_path.toString().trim()) ? file(params.samtools_path).toAbsolutePath().toString() : 'samtools'
params.tabix = (params.tabix_path && params.tabix_path.toString().trim()) ? file(params.tabix_path).toAbsolutePath().toString() : 'tabix'
params.vg = (params.vg_path && params.vg_path.toString().trim()) ? file(params.vg_path).toAbsolutePath().toString() : 'vg'
checkVgVersion(params.vg)
params.bgzip = (params.bgzip_path && params.bgzip_path.toString().trim()) ? file(params.bgzip_path).toAbsolutePath().toString() : 'bgzip'
params.kmc = (params.kmc_path && params.kmc_path.toString().trim()) ? file(params.kmc_path).toAbsolutePath().toString() : 'kmc'
params.python = (params.python_path && params.python_path.toString().trim()) ? file(params.python_path).toAbsolutePath().toString() : 'python3'

if (!params.fq_dir_glob) {
    error "[ERROR] --fq_dir_glob is required."
}
if (!params.index_dir) {
    error "[ERROR] --index_dir is required."
}
def panel_dir_value = params.panel_dir?.toString()?.trim()
if (!panel_dir_value) {
    panel_dir_value = params.index_dir
}
def index_dir = file(params.index_dir, checkIfExists: true)
def panel_dir = file(panel_dir_value, checkIfExists: true)
def panel_name = panel_dir.name.replaceFirst(/(?i)_VarsGT_Index$/, '')
def index_paths = [
    gbz: new File(index_dir.toString(), "Nip_42_rice.gbz"),
    hapl: new File(index_dir.toString(), "Nip_42_rice.hapl"),
    ref: new File(index_dir.toString(), "Nip.chrnum.sorted.fa")
]

def findDirFiles = { dir, pattern ->
    dir.listFiles()?.findAll { it.isFile() && it.name ==~ pattern } ?: []
}

def prefix_files = findDirFiles(index_dir, /.*\.graph_prefix\.txt/)
if (prefix_files.size() != 1) {
    error "[ERROR] Expected exactly one *.graph_prefix.txt in ${index_dir}, found ${prefix_files.size()}."
}

def ref_path_files = findDirFiles(index_dir, /.*\.ref_order\.txt/)
if (ref_path_files.size() != 1) {
    error "[ERROR] Expected exactly one *.ref_order.txt in ${index_dir}, found ${ref_path_files.size()}."
}

def panel_vcfs = findDirFiles(panel_dir, /.*\.ref_panel\.vcf\.gz/)
if (panel_vcfs.size() != 1) {
    error "[ERROR] Expected exactly one *.ref_panel.vcf.gz in ${panel_dir}, found ${panel_vcfs.size()}."
}
def resolved_ref_impute_panel_vcf = panel_vcfs[0].toString()
params.beagle = file(params.beagle_path, checkIfExists: true).toAbsolutePath().toString()

def snp_site_files = findDirFiles(panel_dir, /.*\.snp\.sites\.vcf(\.gz)?/)
def indel_site_files = findDirFiles(panel_dir, /.*\.indel\.sites\.vcf(\.gz)?/)
def sv_site_files = findDirFiles(panel_dir, /.*\.(delly\.)?sv\.sites\.(bcf|vcf|vcf\.gz)/)

if (snp_site_files.size() > 1) {
    error "[ERROR] SNP mode requires at most one SNP sites VCF in ${panel_dir}."
}
if (indel_site_files.size() > 1) {
    error "[ERROR] INDEL mode requires at most one INDEL sites VCF in ${panel_dir}."
}
if (sv_site_files.size() > 1) {
    error "[ERROR] SV mode requires at most one SV sites file in ${panel_dir}."
}

params.run_snp = snp_site_files.size() == 1
params.run_indel = indel_site_files.size() == 1
params.run_sv = sv_site_files.size() == 1
params.run_any_genotyping = params.run_snp || params.run_indel || params.run_sv

if (!params.run_any_genotyping) {
    error "[ERROR] No complete SNP, INDEL, or SV resource set found in ${panel_dir}."
}

def required_paths = index_paths.findAll { key, path ->
    key in ['gbz', 'hapl', 'ref']
}
def missing_resources = required_paths.findAll { key, path -> !path.exists() }.collect { key, path -> "${key}: ${path}" }
if (missing_resources) {
    error "[ERROR] Missing VarsGT index resources:\n  - ${missing_resources.join('\n  - ')}"
}

def resolved_prefix = prefix_files[0].text.trim()
def resolved_sv_sites_file = params.run_sv ? sv_site_files[0].toString() : null
def resolved_gbz = index_paths.gbz.toString()
def resolved_hapl = index_paths.hapl.toString()
def resolved_ref_paths = ref_path_files[0].toString()
def resolved_ref = index_paths.ref.toString()
def resolved_snp_site_vcf = params.run_snp ? snp_site_files[0].toString() : null
def resolved_indel_site_vcf = params.run_indel ? indel_site_files[0].toString() : null

if (params.validate_only ?: false) {
    println "[INFO] VarsGT input validation completed successfully."
    println "[INFO] FASTQ glob: ${params.fq_dir_glob}"
    println "[INFO] Index directory: ${index_dir}"
    println "[INFO] Panel directory: ${panel_dir}"
    println "[INFO] Enabled variant types: ${[
        params.run_snp ? 'SNP' : null,
        params.run_indel ? 'INDEL' : null,
        params.run_sv ? 'SV' : null
    ].findAll().join(', ')}"
    System.exit(0)
}

include { kmc_kmer; giraffe_mapping } from './modules/giraffe_map'
include { bam_addreplacerg; bam_sort_by_name; bam_fixmate; bam_sort_by_pos; bam_markdup; bam_index } from './modules/bam_format'
include { INDEX_REFERENCE; PREPARE_SNP_INDEL_SITES; HAPLOTYPE_CALLER_SNP_INDEL; FILL_MISSING_SNP_INDEL_SITES; MERGE_AND_FORMAT_SNP_INDEL } from './modules/snp_indel_gt'
include { DELLY_SV_GENOTYPE; BCFTOOLS_MERGE_GENOTYPE } from './modules/sv_gt'
include { CONCAT_SNP_INDEL; CONCAT_SNP_SV; CONCAT_INDEL_SV; CONCAT_SNP_INDEL_SV; BEAGLE_IMPUTATION; POP_SNP; POP_INDEL; POP_SV; EXTRACT_SAMPLES_ORDER } from './modules/utils'

workflow {
    println "[INFO] Index directory: ${index_dir}"
    println "[INFO] Panel directory: ${panel_dir}"
    println "[INFO] Enabled variant types: ${[
        params.run_snp ? 'SNP' : null,
        params.run_indel ? 'INDEL' : null,
        params.run_sv ? 'SV' : null
    ].findAll().join(', ')}"
    reads_ch = Channel.fromFilePairs(params.fq_dir_glob, size: 2, flat: true, checkIfExists: true)
    gbz_ch = Channel.fromPath(resolved_gbz, checkIfExists: true).first()
    hapl_ch = Channel.fromPath(resolved_hapl, checkIfExists: true).first()
    ref_path_ch = Channel.fromPath(resolved_ref_paths, checkIfExists: true).first()
    kmer_ch = kmc_kmer(reads_ch)
    reads_kmer_ch = reads_ch.join(kmer_ch)
    mapping_input_ch = reads_kmer_ch
        .combine(gbz_ch)
        .combine(hapl_ch)
        .combine(ref_path_ch)
        .map { sample_id, fq1, fq2, kff, gbz, hapl, ref_path ->
            tuple(sample_id, fq1, fq2, gbz, hapl, kff, ref_path.toString())
        }
    bam_ch = giraffe_mapping(mapping_input_ch)
        .map { sample_id, bam -> tuple(sample_id, bam) }
    rg_bam_ch = bam_addreplacerg(bam_ch)
    qname_bam_ch = bam_sort_by_name(rg_bam_ch)
    fixmate_bam_ch = bam_fixmate(qname_bam_ch)
    pos_bam_ch = bam_sort_by_pos(fixmate_bam_ch, resolved_prefix)
    markdup_bam_ch = bam_markdup(pos_bam_ch)
    indexed_bam_ch = bam_index(markdup_bam_ch)

    // GATK-DELLY genotyping workflow.
    if (params.run_any_genotyping) {
        // Reference and Picard files (required for any genotyping)
        ref = file(resolved_ref, checkIfExists: true)
        picard = file(params.picard, checkIfExists: true)
        
        // Index reference genome (always needed for GATK)
        index_ref_ch = INDEX_REFERENCE(ref, picard, params.threads, params.samtools, params.java)
        
        // SNP and INDEL known alleles are combined once. GATK4 HaplotypeCaller
        // then runs per sample because it is a single-sample caller.
        if (params.run_snp || params.run_indel) {
            def small_variant_site_paths = []
            if (params.run_snp) {
                small_variant_site_paths << file(resolved_snp_site_vcf, checkIfExists: true)
            }
            if (params.run_indel) {
                small_variant_site_paths << file(resolved_indel_site_vcf, checkIfExists: true)
            }
            small_variant_sites_ch = Channel.value(small_variant_site_paths)
            prepared_sites_ch = PREPARE_SNP_INDEL_SITES(
                small_variant_sites_ch, params.out_dir, params.threads,
                params.project, params.bcftools
            )
            sample_small_variant_ch = HAPLOTYPE_CALLER_SNP_INDEL(
                indexed_bam_ch, ref, index_ref_ch.fai, index_ref_ch.dict,
                prepared_sites_ch.sites_vcf, prepared_sites_ch.sites_vcf_index,
                params.out_dir, params.threads, params.java, params.gatk_memory,
                params.gatk, params.gatk_interval_padding, params.tabix
            )
            complete_sample_small_variant_ch = FILL_MISSING_SNP_INDEL_SITES(
                sample_small_variant_ch.vcf,
                prepared_sites_ch.sites_vcf, prepared_sites_ch.sites_vcf_index,
                params.out_dir, params.threads, params.bcftools,
                params.bgzip
            )
            complete_sample_vcf_list_ch = complete_sample_small_variant_ch.vcf
                .toSortedList { a, b -> a[0].toString() <=> b[0].toString() }
                .map { rows -> rows.collectMany { sample_id, vcf, tbi -> [vcf, tbi] } }
            small_variant_format_ch = MERGE_AND_FORMAT_SNP_INDEL(
                complete_sample_vcf_list_ch, params.out_dir, params.threads,
                params.project, params.bcftools, params.bgzip
            )
        }

        // SV genotyping with DELLY, enabled only when a DELLY sites BCF/VCF exists.
        if (params.run_sv) {
            sv_sites = file(resolved_sv_sites_file, checkIfExists: true)
            sv_genotype_ch = DELLY_SV_GENOTYPE(
                ref, sv_sites, indexed_bam_ch, params.out_dir, params.delly, params.bcftools
            )
            sv_bcfs_ch = sv_genotype_ch
                .toSortedList { a, b -> a[0].toString() <=> b[0].toString() }
                .map { sorted ->
                    tuple(
                        sorted.collect { it[1] },
                        sorted.collect { it[2] }
                    )
                }
            if (params.run_indel) {
                sv_samples_order_ch = small_variant_format_ch.samples_order
            } else if (params.run_snp) {
                sv_samples_order_ch = small_variant_format_ch.samples_order
            } else {
                first_sv_bcf_ch = sv_genotype_ch.first().map { sample_id, bcf, csi -> bcf }
                sv_samples_order_ch = EXTRACT_SAMPLES_ORDER(
                    first_sv_bcf_ch, params.out_dir, params.bcftools
                ).samples_order
            }
            sv_merged_ch = BCFTOOLS_MERGE_GENOTYPE(
                sv_bcfs_ch.map { bcfs, indexes -> bcfs },
                sv_bcfs_ch.map { bcfs, indexes -> indexes },
                sv_samples_order_ch, params.out_dir, params.project,
                params.bcftools, params.assign_id
            )
        }
        
        // HaplotypeCaller already emits one SNP+INDEL VCF. Only SV still needs concatenation.
        if ((params.run_snp || params.run_indel) && params.run_sv) {
            if (params.run_snp && params.run_indel) {
                concat_vcf_ch = CONCAT_SNP_SV(
                    small_variant_format_ch.vcf, small_variant_format_ch.tbi,
                    sv_merged_ch.vcf_gz, sv_merged_ch.vcf_gz_index,
                    params.out_dir, params.project, params.bcftools
                )
            } else if (params.run_snp) {
                concat_vcf_ch = CONCAT_SNP_SV(
                    small_variant_format_ch.vcf, small_variant_format_ch.tbi, sv_merged_ch.vcf_gz,
                    sv_merged_ch.vcf_gz_index, params.out_dir, params.project, params.bcftools
                )
            } else {
                concat_vcf_ch = CONCAT_INDEL_SV(
                    small_variant_format_ch.vcf, small_variant_format_ch.tbi,
                    sv_merged_ch.vcf_gz, sv_merged_ch.vcf_gz_index,
                    params.out_dir, params.project, params.bcftools
                )
            }
            beagle_input_vcf = concat_vcf_ch.snp_indel_sv_vcf
        } else {
            if (params.run_snp || params.run_indel) {
                beagle_input_vcf = small_variant_format_ch.vcf
            } else if (params.run_sv) {
                beagle_input_vcf = sv_merged_ch.vcf_gz
            }
        }
        
        // BEAGLE Imputation (always runs after genotyping)
        beagle_impute_biallelic_ch = BEAGLE_IMPUTATION(
            beagle_input_vcf, params.out_dir, params.java, params.beagle,
            resolved_ref_impute_panel_vcf, params.bcftools, params.bgzip
        )
        
        // POP processes - only run if corresponding genotyping was performed
        if (params.run_snp) {
            pop_snp_ch = POP_SNP(
                beagle_impute_biallelic_ch.impute_biallelic_vcf,
                params.out_dir, params.project, params.bcftools
            )
        }
        if (params.run_indel) {
            pop_indel_ch = POP_INDEL(
                beagle_impute_biallelic_ch.impute_biallelic_vcf,
                params.out_dir, params.project, params.bcftools
            )
        }
        if (params.run_sv) {
            pop_sv_ch = POP_SV(
                beagle_impute_biallelic_ch.impute_biallelic_vcf,
                params.out_dir, params.project, params.bcftools
            )
        }
    }
}



