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
params.gbz = null
params.out_dir = "output_dir"
params.ref_paths = null

params.giraffe_mapping_memory_per_task = null
params.giraffe_mapping_cpus_per_task = null
params.giraffe_mapping_parallel_number = null

// GATK-DELLY Genotyping parameters
params.project = "cohort"
params.ref = null
params.snp_site_vcf = null
params.indel_site_vcf = null
params.snp_markers_intervals = null
params.indel_markers_intervals = null
params.sv_sites_vcf = null
// Optional tool paths - if not specified, tools will be used from system PATH
params.gatk_java_path = null  // Java 8 path for GATK UnifiedGenotyper only (required for GATK 3.7)
params.java_path = null       // Java path for other tools (Picard, etc.)
params.delly_path = null
params.bcftools_path = null
params.samtools_path = null
params.tabix_path = null
def f = file(params.prefix_file)
if( !f.exists() ) {
    error "Prefix file not found: ${params.prefix_file}"
}
params.prefix = f.text.trim()


// Required software paths (JAR files)
params.gatk_path = "./softwares/GenomeAnalysisTK3.7.jar"
params.picard_path = null

// Resource configuration (with defaults)
params.threads = 48
params.gatk_memory = '100g'

// Fixed path for assign_id script (from submodule)
def assign_id_path = './scripts/assign_id.sh'
params.assign_id = file(assign_id_path).toAbsolutePath()

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
params.delly = (params.delly_path && params.delly_path.toString().trim()) ? file(params.delly_path).toAbsolutePath().toString() : 'delly'
params.bcftools = (params.bcftools_path && params.bcftools_path.toString().trim()) ? file(params.bcftools_path).toAbsolutePath().toString() : 'bcftools'
params.samtools = (params.samtools_path && params.samtools_path.toString().trim()) ? file(params.samtools_path).toAbsolutePath().toString() : 'samtools'
params.tabix = (params.tabix_path && params.tabix_path.toString().trim()) ? file(params.tabix_path).toAbsolutePath().toString() : 'tabix'
params.beagle = (params.beagle_path && params.beagle_path.toString().trim()) ? file(params.beagle_path).toAbsolutePath().toString() : null
params.ref_impute_panel_vcf = (params.ref_impute_panel_vcf_path && params.ref_impute_panel_vcf_path.toString().trim()) ? file(params.ref_impute_panel_vcf_path).toAbsolutePath().toString() : null
params.vg = (params.vg_path && params.vg_path.toString().trim()) ? file(params.vg_path).toAbsolutePath().toString() : 'vg'
params.bgzip = (params.bgzip_path && params.bgzip_path.toString().trim()) ? file(params.bgzip_path).toAbsolutePath().toString() : 'bgzip'
params.kmc = (params.kmc_path && params.kmc_path.toString().trim()) ? file(params.kmc_path).toAbsolutePath().toString() : 'kmc'

include { kmc_kmer; giraffe_mapping } from './modules/giraffe_map'
include { bam_addreplacerg; bam_sort_by_name; bam_fixmate; bam_sort_by_pos; bam_markdup; bam_index } from './modules/bam_format'
include { INDEX_REFERENCE; UNIFIED_GENOTYPER_SNP; UNIFIED_GENOTYPER_INDEL; GATK_SNP_FORMAT; GATK_INDEL_FORMAT } from './modules/snp_indel_gt'
include { DELLY_SV_GENOTYPE; BCFTOOLS_MERGE_GENOTYPE } from './modules/sv_gt'
include { CONCAT_VCF; BEAGLE_IMPUTATION; POP_SNP; POP_INDEL; POP_SV } from './modules/utils'

workflow {

    gbz_ch      = Channel.fromPath(params.gbz)
    hapl_ch     = Channel.fromPath(params.hapl)
    reads_ch    = Channel.fromFilePairs(params.fq_dir_glob, size: 2, flat: true)
                 // => tuple(sample_id, fq1, fq2)
    
    // Generate kmer files for each sample
    kmer_ch = kmc_kmer(reads_ch)  // => tuple(sample_id, kff_file)
    
    // Combine reads with kmer files
    reads_kmer_ch = reads_ch
        .join(kmer_ch)  // => tuple(sample_id, fq1, fq2, kff_file)
    
    // ref_paths is optional
    if (params.ref_paths) {
        ref_path_ch = Channel.fromPath(params.ref_paths).first()
        // Combine: reads_kmer + idx + ref_path
        mapping_input_ch = reads_kmer_ch
            .combine(gbz_ch)        // => tuple(sample_id, fq1, fq2, kff, gbz)
            .combine(hapl_ch)        // => tuple(sample_id, fq1, fq2, kff, gbz, hapl)
            .combine(ref_path_ch)   // => tuple(sample_id, fq1, fq2, kff, gbz, hapl, ref_path)
            .map { sample_id, fq1, fq2, kff, gbz, hapl, ref_path ->
                tuple(sample_id, fq1, fq2, gbz, hapl, kff, ref_path.toString())
            }
    } else {
        // Combine: reads_kmer + idx (no ref_path)
        mapping_input_ch = reads_kmer_ch
            .combine(gbz_ch)        // => tuple(sample_id, fq1, fq2, kff, gbz)
            .combine(hapl_ch)        // => tuple(sample_id, fq1, fq2, kff, gbz, hapl)
            .map { sample_id, fq1, fq2, kff, gbz, hapl -> 
                tuple(sample_id, fq1, fq2, gbz, hapl, kff, null)
            }
    }

    bam_ch = giraffe_mapping(mapping_input_ch)
        .map { sample_id, bam -> 
            tuple(sample_id, bam)
        }  // => tuple(sample_id, bam)

    rg_bam_ch = bam_addreplacerg(bam_ch)  // => tuple(sample_id, rg.bam)
    qname_bam_ch = bam_sort_by_name(rg_bam_ch)  // => tuple(sample_id, qname.bam)
    fixmate_bam_ch = bam_fixmate(qname_bam_ch)  // => tuple(sample_id, fixmate.bam)
    pos_bam_ch = bam_sort_by_pos(fixmate_bam_ch, params.prefix)  // => tuple(sample_id, pos.bam)
    markdup_bam_ch = bam_markdup(pos_bam_ch)  // => tuple(sample_id, markdup.bam)
    indexed_bam_ch = bam_index(markdup_bam_ch)  // => tuple(sample_id, markdup.bam, markdup.bam.bai)

    // GATK-DELLY Genotyping workflow (only if parameters are provided)
    if (params.ref && params.picard && params.snp_site_vcf && params.indel_site_vcf && params.sv_sites_vcf && params.snp_markers_intervals && params.indel_markers_intervals) {
        // Collect BAM files for GATK UnifiedGenotyper
        bam_list_ch = indexed_bam_ch.map { sample_id, bam, bai -> [ bam, bai ] }.collect()
        
        // Prepare BAM tuple channel for DELLY (sample_id, bam, bai)
        bam_tuples_ch = indexed_bam_ch.map { sample_id, bam, bai -> tuple(sample_id, bam, bai) }

        // Index reference genome
        ref = file(params.ref, checkIfExists: true)
        picard = file(params.picard, checkIfExists: true)
        snp_markers_intervals = file(params.snp_markers_intervals, checkIfExists: true)
        indel_markers_intervals = file(params.indel_markers_intervals, checkIfExists: true)
        snp_site_vcf = file(params.snp_site_vcf, checkIfExists: true)
        indel_site_vcf = file(params.indel_site_vcf, checkIfExists: true)
        sv_sites_vcf = file(params.sv_sites_vcf, checkIfExists: true)

        index_ref_ch = INDEX_REFERENCE(ref, picard)
        
        // SNP and INDEL genotyping
        snp_vcf_ch = UNIFIED_GENOTYPER_SNP(ref, bam_list_ch, index_ref_ch.fai, index_ref_ch.dict, snp_markers_intervals, snp_site_vcf)
        indel_vcf_ch = UNIFIED_GENOTYPER_INDEL(ref, bam_list_ch, index_ref_ch.fai, index_ref_ch.dict, indel_markers_intervals, indel_site_vcf)

        snp_format_ch = GATK_SNP_FORMAT(snp_vcf_ch.vcf, snp_vcf_ch.tbi, snp_site_vcf)
        indel_format_ch = GATK_INDEL_FORMAT(indel_vcf_ch.vcf_gz, indel_vcf_ch.vcf_gz_index, indel_site_vcf)

        // SV genotyping
        sv_gt_ch = DELLY_SV_GENOTYPE(ref, sv_sites_vcf, bam_tuples_ch)

        bcf_list_ch = sv_gt_ch.map { sample_id, bcf, bcf_index -> bcf}.collect()
        bcf_index_list_ch = sv_gt_ch.map { sample_id, bcf, bcf_index -> bcf_index}.collect()
        
        sv_merged_ch = BCFTOOLS_MERGE_GENOTYPE(bcf_list_ch, bcf_index_list_ch, indel_format_ch.samples_order)

        // Concatenate all variant types
        concat_vcf_ch = CONCAT_VCF(snp_format_ch.vcf, snp_format_ch.tbi, indel_format_ch.vcf_gz, indel_format_ch.vcf_gz_index, sv_merged_ch.vcf_gz, sv_merged_ch.vcf_gz_index)

        beagle_impute_biallelic_ch = BEAGLE_IMPUTATION(concat_vcf_ch.snp_indel_sv_vcf)
        pop_snp_ch = POP_SNP(beagle_impute_biallelic_ch.impute_biallelic_vcf)
        pop_indel_ch = POP_INDEL(beagle_impute_biallelic_ch.impute_biallelic_vcf)
        pop_sv_ch = POP_SV(beagle_impute_biallelic_ch.impute_biallelic_vcf)
    }
}



