#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

def checkJava8(java_cmd) {
    def proc = ["bash", "-c", "${java_cmd} -version 2>&1"].execute()
    proc.waitFor()
    def output = proc.text

    if (!(output =~ /version "1\.8\./)) {
        error """
        [ERROR] GATK requires Java 8, but detected:

        ${output}

        Please set:
        params.gatk_java_path = "/path/to/java8/bin/java"
        """
    } else {
        println "[INFO] GATK Java version OK:"
        println output
    }
}
def findJava8() {

    // find all java
    def proc = ["bash", "-c", "which -a java 2>/dev/null | uniq"].execute()
    proc.waitFor()
    def java_list = proc.text.readLines()

    if (!java_list || java_list.size() == 0) {
        error "[ERROR] No Java executable found in PATH"
    }

    println "[INFO] Found Java candidates:"
    java_list.each { println "  - ${it}" }

    // check each version
    for (j in java_list) {
        def p = ["bash", "-c", "${j} -version 2>&1"].execute()
        p.waitFor()
        def out = p.text

        if (out =~ /version "1\.8\./) {
            println "[INFO] Java 8 detected: ${j}"
            println out
            return j
        }
    }

    // if not found Java 8
    error """
    [ERROR] No Java 8 found in PATH.

    Detected Java versions:
    ${java_list.collect { j ->
        def p = ["bash", "-c", "${j} -version 2>&1"].execute()
        p.waitFor()
        "${j} -> ${p.text.split('\\n')[0]}"
    }.join('\n\t')}

    Please install Java 8 and ensure it is available in PATH,
    or explicitly set:
    gatk_java_path = "/path/to/java8/bin/java"
    in your params.yaml file.
    """
}

params.fq_dir_glob = null
params.index_dir = null
params.gbz = null
params.out_dir = "output_dir"
params.ref_paths = null

params.kmc_max_parallel_number = 4
params.kmc_cpus_per_task = 16
params.kmc_memory_per_task = "32 GB"
params.bam_per_task_threads = 4
params.bam_per_task_memory = "8 GB"
params.bam_max_parallel_num = 4
params.giraffe_mapping_memory_per_task = "40 GB"
params.giraffe_mapping_cpus_per_task = 16
params.giraffe_mapping_parallel_number = 4
params.beagle_memory = "100 GB"
params.beagle_cpus = 32

// GATK-PanGenie genotyping parameters
params.project = "cohort"
params.ref = null
params.snp_site_vcf = null
params.indel_site_vcf = null
params.snp_markers_intervals = null
params.indel_markers_intervals = null
params.pangenie_reference = null
params.pangenie_panel_vcf = null
params.pangenie_biallelic_vcf = null
params.pangenie_index = null
// Optional tool paths - if not specified, tools will be used from system PATH
params.gatk_java_path = null  // Java 8 path for GATK UnifiedGenotyper only (required for GATK 3.7)
params.java_path = null       // Java path for other tools (Picard, etc.)
params.bcftools_path = null
params.samtools_path = null
params.tabix_path = null
params.pangenie_path = null
params.python_path = null
params.ref_impute_panel_vcf_path = null
params.vg_path = null
params.bgzip_path = null
params.kmc_path = null
// Required software paths (JAR files)
params.gatk_path = baseDir.resolve("softwares/GenomeAnalysisTK3.7.jar").toString()
params.picard_path = baseDir.resolve("softwares/picard.jar").toString()
params.beagle_path = baseDir.resolve("softwares/beagle.27Feb25.75f.jar").toString()

// Resource configuration (with defaults)
params.threads = 48
params.gatk_memory = '100g'

// Fixed paths for repository utility scripts.
params.assign_id = baseDir.resolve("scripts/assign_id.sh").toFile()
params.vcf_natural_sort = baseDir.resolve("scripts/vcf_natural_sort.sh").toFile()
params.convert_script = baseDir.resolve("scripts/convert-to-biallelic.py").toFile()

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

// Set tool executables - use specified path if provided, otherwise use tool name (from PATH)
// Handle both null and empty string cases
// GATK Java (Java 8) - for GATK UnifiedGenotyper only (GATK 3.7 requires Java 8)
if (params.gatk_java_path && params.gatk_java_path.toString().trim()) {
    params.gatk_java = file(params.gatk_java_path).toAbsolutePath().toString()
    checkJava8(params.gatk_java)   // manually specified → strong check
} else {
    params.gatk_java = findJava8() // automatically find Java 8
}
// General Java - for Picard and other tools (can use newer Java versions)
params.java = (params.java_path && params.java_path.toString().trim()) ? file(params.java_path).toAbsolutePath().toString() : 'java'
params.bcftools = (params.bcftools_path && params.bcftools_path.toString().trim()) ? file(params.bcftools_path).toAbsolutePath().toString() : 'bcftools'
params.samtools = (params.samtools_path && params.samtools_path.toString().trim()) ? file(params.samtools_path).toAbsolutePath().toString() : 'samtools'
params.tabix = (params.tabix_path && params.tabix_path.toString().trim()) ? file(params.tabix_path).toAbsolutePath().toString() : 'tabix'
params.vg = (params.vg_path && params.vg_path.toString().trim()) ? file(params.vg_path).toAbsolutePath().toString() : 'vg'
params.bgzip = (params.bgzip_path && params.bgzip_path.toString().trim()) ? file(params.bgzip_path).toAbsolutePath().toString() : 'bgzip'
params.kmc = (params.kmc_path && params.kmc_path.toString().trim()) ? file(params.kmc_path).toAbsolutePath().toString() : 'kmc'
params.pangenie = (params.pangenie_path && params.pangenie_path.toString().trim()) ? file(params.pangenie_path).toAbsolutePath().toString() : 'PanGenie'
params.python = (params.python_path && params.python_path.toString().trim()) ? file(params.python_path).toAbsolutePath().toString() : 'python3'

if (!params.fq_dir_glob) {
    error "[ERROR] --fq_dir_glob is required."
}
if (!params.index_dir) {
    error "[ERROR] --index_dir is required."
}
def panel_dir = file(params.index_dir, checkIfExists: true)
def panel_name = panel_dir.name.replace('_VarsGT_index', '')
def panel_paths = [
    prefix_file: new File(panel_dir.toString(), "${panel_name}_graph_prefix.txt"),
    gbz: new File(panel_dir.toString(), "Nip_42_rice.gbz"),
    hapl: new File(panel_dir.toString(), "Nip_42_rice.hapl"),
    ref_paths: new File(panel_dir.toString(), "Nip.ref_order.txt"),
    ref: new File(panel_dir.toString(), "Nip.chrnum.sorted.fa"),
    snp_site_vcf: new File(panel_dir.toString(), "${panel_name}.snp.sites.vcf"),
    indel_site_vcf: new File(panel_dir.toString(), "${panel_name}.indel.sites.vcf"),
    snp_markers_intervals: new File(panel_dir.toString(), "${panel_name}.snp.markers.intervals"),
    indel_markers_intervals: new File(panel_dir.toString(), "${panel_name}.indel.markers.intervals"),
    pangenie_reference: new File(panel_dir.toString(), "Nip_GraphName.fa"),
    pangenie_panel_vcf: new File(panel_dir.toString(), "Nip_42_rice.filtered_ids.vcf"),
    pangenie_biallelic_vcf: new File(panel_dir.toString(), "Nip_42_rice.filtered_ids_biallelic.vcf.gz"),
    pangenie_index: new File(panel_dir.toString(), "Nip_42_rice_pangenie.index")
]

def panel_vcfs = panel_dir.listFiles()?.findAll { it.name ==~ /.*\.full\.all\.impute\.vcf\.gz/ } ?: []
if (panel_vcfs.size() != 1) {
    error "[ERROR] Expected exactly one *.full.all.impute.vcf.gz in ${panel_dir}, found ${panel_vcfs.size()}."
}
def resolved_ref_impute_panel_vcf = panel_vcfs[0].toString()
params.beagle = file(params.beagle_path, checkIfExists: true).toAbsolutePath().toString()

def sv_site_files = panel_dir.listFiles()?.findAll {
    it.isFile() && it.name ==~ /.*\.sv\.sites\.(tsv|vcf|txt)(\.gz)?/
} ?: []
if (sv_site_files.size() != 1) {
    error "[ERROR] Expected exactly one *.sv.sites.tsv, *.sv.sites.vcf, or *.sv.sites.txt in ${panel_dir}, found ${sv_site_files.size()}."
}

def missing_resources = panel_paths.findAll { key, path -> !path.exists() }.collect { key, path -> "${key}: ${path}" }
if (missing_resources) {
    error "[ERROR] Missing VarsGT index resources:\n  - ${missing_resources.join('\n  - ')}"
}

def resolved_prefix = panel_paths.prefix_file.text.trim()
def resolved_sv_sites_file = sv_site_files[0].toString()
def resolved_gbz = panel_paths.gbz.toString()
def resolved_hapl = panel_paths.hapl.toString()
def resolved_ref_paths = panel_paths.ref_paths.toString()
def resolved_ref = panel_paths.ref.toString()
def resolved_snp_site_vcf = panel_paths.snp_site_vcf.toString()
def resolved_indel_site_vcf = panel_paths.indel_site_vcf.toString()
def resolved_snp_intervals = panel_paths.snp_markers_intervals.toString()
def resolved_indel_intervals = panel_paths.indel_markers_intervals.toString()
def resolved_pangenie_biallelic_vcf = panel_paths.pangenie_biallelic_vcf.toString()
def resolved_pangenie_index = panel_paths.pangenie_index.toString()
params.run_snp = true
params.run_indel = true
params.run_sv = true
params.run_any_genotyping = true

if (params.validate_only ?: false) {
    println "[INFO] VarsGT input validation completed successfully."
    println "[INFO] FASTQ glob: ${params.fq_dir_glob}"
    println "[INFO] Index directory: ${panel_dir}"
    println "[INFO] SV sites file: ${resolved_sv_sites_file}"
    System.exit(0)
}

include { kmc_kmer; giraffe_mapping } from './modules/giraffe_map'
include { bam_addreplacerg; bam_sort_by_name; bam_fixmate; bam_sort_by_pos; bam_markdup; bam_index } from './modules/bam_format'
include { INDEX_REFERENCE; UNIFIED_GENOTYPER_SNP; UNIFIED_GENOTYPER_INDEL; GATK_SNP_FORMAT; GATK_INDEL_FORMAT; TABIX_SNP; TABIX_INDEL } from './modules/snp_indel_gt'
include { PANGENIE_GENOTYPE; CONVERT_BIALLELIC; COMPRESS_VCF; MERGE_VCF; FINALIZE_VCF } from './modules/pangenie'
include { CONCAT_SNP_INDEL; CONCAT_SNP_SV; CONCAT_INDEL_SV; CONCAT_SNP_INDEL_SV; BEAGLE_IMPUTATION; POP_SNP; POP_INDEL; POP_SV } from './modules/utils'

workflow {
    println "[INFO] FASTQ-only mode: running Giraffe for SNP/INDEL and PanGenie for SV."
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

    pangenie_index_ch = Channel.fromPath("${resolved_pangenie_index}/index_path_segments.fasta", checkIfExists: true)
        .map { it.parent }
        .first()
    pangenie_input_ch = reads_ch
        .combine(pangenie_index_ch)
        .map { sample_id, fq1, fq2, index_dir -> tuple(sample_id, fq1, fq2, index_dir) }
    pangenie_genotyped_ch = PANGENIE_GENOTYPE(pangenie_input_ch)
    pangenie_convert_ch = pangenie_genotyped_ch
        .combine(Channel.fromPath(resolved_pangenie_biallelic_vcf, checkIfExists: true).first())
        .combine(Channel.fromPath(params.convert_script, checkIfExists: true).first())
    pangenie_biallelic_ch = CONVERT_BIALLELIC(pangenie_convert_ch)
    pangenie_compressed_ch = COMPRESS_VCF(pangenie_biallelic_ch)
    pangenie_merge_inputs_ch = pangenie_compressed_ch
        .collect()
        .map { rows ->
            def sorted = rows.sort { a, b -> a[0] <=> b[0] }
            tuple(
                sorted.collect { it[0] },
                sorted.collect { it[1] },
                sorted.collect { it[2] }
            )
        }
    pangenie_merged_ch = MERGE_VCF(pangenie_merge_inputs_ch)
    sv_merged_ch = FINALIZE_VCF(
        pangenie_merged_ch,
        Channel.fromPath(params.vcf_natural_sort, checkIfExists: true).first(),
        Channel.fromPath(params.assign_id, checkIfExists: true).first(),
        Channel.fromPath(resolved_sv_sites_file, checkIfExists: true).first()
    )

    // GATK-PanGenie genotyping workflow.
    if (params.run_any_genotyping) {
        // Reference and Picard files (required for any genotyping)
        ref = file(resolved_ref, checkIfExists: true)
        picard = file(params.picard, checkIfExists: true)
        
        // Index reference genome (always needed for GATK)
        index_ref_ch = INDEX_REFERENCE(ref, picard)
        
        // Collect BAM files deterministically for GATK UnifiedGenotyper.
        bam_list_ch = indexed_bam_ch
            .collect()
            .map { rows ->
                rows.sort { a, b -> a[0] <=> b[0] }
                    .collectMany { sample_id, bam, bai -> [bam, bai] }
            }
        
        // SNP genotyping (if snp_site_vcf and snp_markers_intervals are provided)
        if (params.run_snp) {
            snp_markers_intervals = file(resolved_snp_intervals, checkIfExists: true)
            snp_site_vcf = file(resolved_snp_site_vcf, checkIfExists: true)
            snp_vcf_ch = UNIFIED_GENOTYPER_SNP(ref, bam_list_ch, index_ref_ch.fai, index_ref_ch.dict, snp_markers_intervals, snp_site_vcf)
            snp_indexed_ch = TABIX_SNP(snp_vcf_ch.vcf)
            snp_format_ch = GATK_SNP_FORMAT(snp_indexed_ch.vcf, snp_indexed_ch.tbi, snp_site_vcf)
        }
        
        // INDEL genotyping (if indel_site_vcf and indel_markers_intervals are provided)
        if (params.run_indel) {
            indel_markers_intervals = file(resolved_indel_intervals, checkIfExists: true)
            indel_site_vcf = file(resolved_indel_site_vcf, checkIfExists: true)
            indel_vcf_ch = UNIFIED_GENOTYPER_INDEL(ref, bam_list_ch, index_ref_ch.fai, index_ref_ch.dict, indel_markers_intervals, indel_site_vcf)
            indel_indexed_ch = TABIX_INDEL(indel_vcf_ch.vcf_gz)
            indel_format_ch = GATK_INDEL_FORMAT(indel_indexed_ch.vcf_gz, indel_indexed_ch.vcf_gz_index, indel_site_vcf)
        }
        
        // Concatenate all variant types (only if multiple types are enabled)
        def variant_type_count = [params.run_snp, params.run_indel, params.run_sv].count(true)
        
        if (variant_type_count > 1) {
            // Multiple variant types - need to concatenate
            if (params.run_snp && params.run_indel && params.run_sv) {
                // All three types
                concat_vcf_ch = CONCAT_SNP_INDEL_SV(snp_format_ch.vcf, snp_format_ch.tbi, indel_format_ch.vcf_gz, indel_format_ch.vcf_gz_index, sv_merged_ch.vcf_gz, sv_merged_ch.vcf_gz_index)
            } else if (params.run_snp && params.run_indel) {
                // SNP + INDEL
                concat_vcf_ch = CONCAT_SNP_INDEL(snp_format_ch.vcf, snp_format_ch.tbi, indel_format_ch.vcf_gz, indel_format_ch.vcf_gz_index)
            } else if (params.run_snp && params.run_sv) {
                // SNP + SV
                concat_vcf_ch = CONCAT_SNP_SV(snp_format_ch.vcf, snp_format_ch.tbi, sv_merged_ch.vcf_gz, sv_merged_ch.vcf_gz_index)
            } else if (params.run_indel && params.run_sv) {
                // INDEL + SV
                concat_vcf_ch = CONCAT_INDEL_SV(indel_format_ch.vcf_gz, indel_format_ch.vcf_gz_index, sv_merged_ch.vcf_gz, sv_merged_ch.vcf_gz_index)
            }
            beagle_input_vcf = concat_vcf_ch.snp_indel_sv_vcf
        } else {
            // Single variant type - no concatenation needed
            if (params.run_snp) {
                beagle_input_vcf = snp_format_ch.vcf
            } else if (params.run_indel) {
                beagle_input_vcf = indel_format_ch.vcf_gz
            } else if (params.run_sv) {
                beagle_input_vcf = sv_merged_ch.vcf_gz
            }
        }
        
        // BEAGLE Imputation (always runs after genotyping)
        beagle_impute_biallelic_ch = BEAGLE_IMPUTATION(beagle_input_vcf)
        
        // POP processes - only run if corresponding genotyping was performed
        if (params.run_snp) {
            pop_snp_ch = POP_SNP(beagle_impute_biallelic_ch.impute_biallelic_vcf)
        }
        if (params.run_indel) {
            pop_indel_ch = POP_INDEL(beagle_impute_biallelic_ch.impute_biallelic_vcf)
        }
        if (params.run_sv) {
            pop_sv_ch = POP_SV(beagle_impute_biallelic_ch.impute_biallelic_vcf)
        }
    }
}



