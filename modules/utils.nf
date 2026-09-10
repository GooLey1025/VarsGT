process CONCAT_SNP_INDEL {
    publishDir params.out_dir, mode: 'copy'
    input:
    path snp_vcf_gz
    path snp_vcf_gz_index
    path indel_vcf_gz
    path indel_vcf_gz_index
    output:
    path "${params.project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${params.project}.snp.indel.sv.vcf.gz.csi", emit: snp_indel_sv_vcf_index
    script:
    """
    set -euo pipefail
    ${params.bcftools} concat -a -Oz -o ${params.project}.snp.indel.sv.vcf.gz ${snp_vcf_gz} ${indel_vcf_gz}
    ${params.bcftools} index -f ${params.project}.snp.indel.sv.vcf.gz
    """
}

process CONCAT_SNP_SV {
    publishDir params.out_dir, mode: 'copy'
    input:
    path snp_vcf_gz
    path snp_vcf_gz_index
    path sv_vcf_gz
    path sv_vcf_gz_index
    output:
    path "${params.project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${params.project}.snp.indel.sv.vcf.gz.csi", emit: snp_indel_sv_vcf_index
    script:
    """
    set -euo pipefail
    ${params.bcftools} concat -a -Oz -o ${params.project}.snp.indel.sv.vcf.gz ${snp_vcf_gz} ${sv_vcf_gz}
    ${params.bcftools} index -f ${params.project}.snp.indel.sv.vcf.gz
    """
}

process CONCAT_INDEL_SV {
    publishDir params.out_dir, mode: 'copy'
    input:
    path indel_vcf_gz
    path indel_vcf_gz_index
    path sv_vcf_gz
    path sv_vcf_gz_index
    output:
    path "${params.project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${params.project}.snp.indel.sv.vcf.gz.csi", emit: snp_indel_sv_vcf_index
    script:
    """
    set -euo pipefail
    ${params.bcftools} concat -a -Oz -o ${params.project}.snp.indel.sv.vcf.gz ${indel_vcf_gz} ${sv_vcf_gz}
    ${params.bcftools} index -f ${params.project}.snp.indel.sv.vcf.gz
    """
}

process CONCAT_SNP_INDEL_SV {
    publishDir params.out_dir, mode: 'copy', pattern: "*.snp.indel.sv.vcf.gz"
    input:
    path snp_vcf_gz
    path snp_vcf_gz_index
    path indel_vcf_gz
    path indel_vcf_gz_index
    path sv_vcf_gz
    path sv_vcf_gz_index
    output:
    path "${params.project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${params.project}.snp.indel.sv.vcf.gz.csi", emit: snp_indel_sv_vcf_index
    script:
    """
    set -euo pipefail
    ${params.bcftools} concat -a -Oz -o ${params.project}.snp.indel.sv.vcf.gz ${snp_vcf_gz} ${indel_vcf_gz} ${sv_vcf_gz}
    ${params.bcftools} index -f ${params.project}.snp.indel.sv.vcf.gz
    """
}

process BEAGLE_IMPUTATION {
    publishDir params.out_dir, mode: 'copy', pattern: "*.impute.biallelic.vcf.gz"
    publishDir params.out_dir, mode: 'copy', pattern: "*.snp.indel.sv.vcf.gz"

    memory "${params.beagle_memory}"
    cpus "${params.beagle_cpus}"
    input:
    path input_vcf

    output:
    path "*.impute.biallelic.vcf.gz", emit: impute_biallelic_vcf

    script:
    """
    mkdir -p ./beagle_TMP
    ${params.java} -Xmx${task.memory.toGiga()}g -Djava.io.tmpdir=./beagle_TMP \
        -jar ${params.beagle} \
        gt=${input_vcf} \
        ref=${params.ref_impute_panel_vcf} \
        out=\$(basename ${input_vcf} .vcf.gz).impute  
    ${params.bcftools} view -h \$(basename ${input_vcf} .vcf.gz).impute.vcf.gz | head -n -1 > header.tmp
    ${params.bcftools} view -h ${input_vcf} >> header.tmp


    ${params.bgzip} \$(basename ${input_vcf} .vcf.gz).impute.vcf.gz -d -c > \$(basename ${input_vcf} .vcf.gz).impute.vcf
    ${params.bcftools} reheader -h header.tmp \$(basename ${input_vcf} .vcf.gz).impute.vcf > \$(basename ${input_vcf} .vcf.gz).impute.reheader.vcf 
    ${params.bcftools} norm -m -both -Oz -o \$(basename ${input_vcf} .vcf.gz).impute.biallelic.vcf.gz \$(basename ${input_vcf} .vcf.gz).impute.reheader.vcf
    ${params.bcftools} index -f \$(basename ${input_vcf} .vcf.gz).impute.biallelic.vcf.gz
    """
}

process POP_SNP {
    publishDir "${params.out_dir}/sub_vcfs/", mode: 'copy', pattern: "*.vcf.gz"
    input:
    path snp_indel_sv_impute_biallelic_vcf
    output:
    path "${params.project}.snp.impute.biallelic.vcf.gz", emit: snp_vcf
    script:
    """
    ${params.bcftools} view -i 'ID ~ "^SNP-"' -Oz -o ${params.project}.snp.impute.biallelic.vcf.gz ${snp_indel_sv_impute_biallelic_vcf}
    """
}

process POP_INDEL {
    publishDir "${params.out_dir}/sub_vcfs/", mode: 'copy', pattern: "*.vcf.gz"
    input:
    path snp_indel_sv_impute_biallelic_vcf
    output:
    path "${params.project}.indel.impute.biallelic.vcf.gz", emit: indel_vcf
    script:
    """
    ${params.bcftools} view -i 'ID ~ "^INDEL-"' -Oz -o ${params.project}.indel.impute.biallelic.vcf.gz ${snp_indel_sv_impute_biallelic_vcf}
    """
}

process POP_SV {
    publishDir "${params.out_dir}/sub_vcfs/", mode: 'copy', pattern: "*.vcf.gz"
    input:
    path snp_indel_sv_impute_biallelic_vcf
    output:
    path "${params.project}.sv.impute.biallelic.vcf.gz", emit: sv_vcf
    script:
    """
    ${params.bcftools} view -i 'ID ~ "^SV-"' ${snp_indel_sv_impute_biallelic_vcf} -Oz -o ${params.project}.sv.impute.biallelic.vcf.gz
    """
}

process EXTRACT_SAMPLES_ORDER {
    publishDir params.out_dir, mode: 'copy', pattern: "*.txt"
    input:
    path vcf_gz
    output:
    path "samples.order.txt", emit: samples_order
    script:
    """
    ${params.bcftools} query -l ${vcf_gz} > samples.order.txt
    """
}