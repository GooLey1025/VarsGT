process CONCAT_SNP_INDEL {
    publishDir { out_dir }, mode: 'copy'
    input:
    path snp_vcf_gz
    path snp_vcf_gz_index
    path indel_vcf_gz
    path indel_vcf_gz_index
    val(out_dir)
    val(project)
    val(bcftools)
    output:
    path "${project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${project}.snp.indel.sv.vcf.gz.csi", emit: snp_indel_sv_vcf_index
    script:
    """
    set -euo pipefail
    ${bcftools} concat -a -Oz -o ${project}.snp.indel.sv.vcf.gz ${snp_vcf_gz} ${indel_vcf_gz}
    ${bcftools} index -f ${project}.snp.indel.sv.vcf.gz
    """
}

process CONCAT_SNP_SV {
    publishDir { out_dir }, mode: 'copy'
    input:
    path snp_vcf_gz
    path snp_vcf_gz_index
    path sv_vcf_gz
    path sv_vcf_gz_index
    val(out_dir)
    val(project)
    val(bcftools)
    output:
    path "${project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${project}.snp.indel.sv.vcf.gz.csi", emit: snp_indel_sv_vcf_index
    script:
    """
    set -euo pipefail
    ${bcftools} concat -a -Oz -o ${project}.snp.indel.sv.vcf.gz ${snp_vcf_gz} ${sv_vcf_gz}
    ${bcftools} index -f ${project}.snp.indel.sv.vcf.gz
    """
}

process CONCAT_INDEL_SV {
    publishDir { out_dir }, mode: 'copy'
    input:
    path indel_vcf_gz
    path indel_vcf_gz_index
    path sv_vcf_gz
    path sv_vcf_gz_index
    val(out_dir)
    val(project)
    val(bcftools)
    output:
    path "${project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${project}.snp.indel.sv.vcf.gz.csi", emit: snp_indel_sv_vcf_index
    script:
    """
    set -euo pipefail
    ${bcftools} concat -a -Oz -o ${project}.snp.indel.sv.vcf.gz ${indel_vcf_gz} ${sv_vcf_gz}
    ${bcftools} index -f ${project}.snp.indel.sv.vcf.gz
    """
}

process CONCAT_SNP_INDEL_SV {
    publishDir { out_dir }, mode: 'copy', pattern: "*.snp.indel.sv.vcf.gz"
    input:
    path snp_vcf_gz
    path snp_vcf_gz_index
    path indel_vcf_gz
    path indel_vcf_gz_index
    path sv_vcf_gz
    path sv_vcf_gz_index
    val(out_dir)
    val(project)
    val(bcftools)
    output:
    path "${project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${project}.snp.indel.sv.vcf.gz.csi", emit: snp_indel_sv_vcf_index
    script:
    """
    set -euo pipefail
    ${bcftools} concat -a -Oz -o ${project}.snp.indel.sv.vcf.gz ${snp_vcf_gz} ${indel_vcf_gz} ${sv_vcf_gz}
    ${bcftools} index -f ${project}.snp.indel.sv.vcf.gz
    """
}

process BEAGLE_IMPUTATION {
    publishDir { out_dir }, mode: 'copy', pattern: "*.impute.biallelic.vcf.gz"
    publishDir { out_dir }, mode: 'copy', pattern: "*.snp.indel.sv.vcf.gz"

    memory params.beagle_memory
    cpus params.beagle_cpus
    input:
    path input_vcf
    val(out_dir)
    val(java)
    path beagle
    path ref_impute_panel_vcf
    val(bcftools)
    val(bgzip)

    output:
    path "*.impute.biallelic.vcf.gz", emit: impute_biallelic_vcf

    script:
    """
    mkdir -p ./beagle_TMP
    ${java} -Xmx${task.memory.toGiga()}g -Djava.io.tmpdir=./beagle_TMP \
        -jar ${beagle} \
        gt=${input_vcf} \
        ref=${ref_impute_panel_vcf} \
        out=\$(basename ${input_vcf} .vcf.gz).impute  
    ${bcftools} view -h \$(basename ${input_vcf} .vcf.gz).impute.vcf.gz | head -n -1 > header.tmp
    ${bcftools} view -h ${input_vcf} >> header.tmp


    ${bgzip} \$(basename ${input_vcf} .vcf.gz).impute.vcf.gz -d -c > \$(basename ${input_vcf} .vcf.gz).impute.vcf
    ${bcftools} reheader -h header.tmp \$(basename ${input_vcf} .vcf.gz).impute.vcf > \$(basename ${input_vcf} .vcf.gz).impute.reheader.vcf 
    ${bcftools} norm -m -both -Oz -o \$(basename ${input_vcf} .vcf.gz).impute.biallelic.vcf.gz \$(basename ${input_vcf} .vcf.gz).impute.reheader.vcf
    ${bcftools} index -f \$(basename ${input_vcf} .vcf.gz).impute.biallelic.vcf.gz
    """
}

process POP_SNP {
    publishDir { "${out_dir}/sub_vcfs/" }, mode: 'copy', pattern: "*.vcf.gz"
    input:
    path snp_indel_sv_impute_biallelic_vcf
    val(out_dir)
    val(project)
    val(bcftools)
    output:
    path "${project}.snp.impute.biallelic.vcf.gz", emit: snp_vcf
    script:
    """
    ${bcftools} view -i 'ID ~ "^SNP-"' -Oz -o ${project}.snp.impute.biallelic.vcf.gz ${snp_indel_sv_impute_biallelic_vcf}
    """
}

process POP_INDEL {
    publishDir { "${out_dir}/sub_vcfs/" }, mode: 'copy', pattern: "*.vcf.gz"
    input:
    path snp_indel_sv_impute_biallelic_vcf
    val(out_dir)
    val(project)
    val(bcftools)
    output:
    path "${project}.indel.impute.biallelic.vcf.gz", emit: indel_vcf
    script:
    """
    ${bcftools} view -i 'ID ~ "^INDEL-"' -Oz -o ${project}.indel.impute.biallelic.vcf.gz ${snp_indel_sv_impute_biallelic_vcf}
    """
}

process POP_SV {
    publishDir { "${out_dir}/sub_vcfs/" }, mode: 'copy', pattern: "*.vcf.gz"
    input:
    path snp_indel_sv_impute_biallelic_vcf
    val(out_dir)
    val(project)
    val(bcftools)
    output:
    path "${project}.sv.impute.biallelic.vcf.gz", emit: sv_vcf
    script:
    """
    ${bcftools} view -i 'ID ~ "^SV-"' ${snp_indel_sv_impute_biallelic_vcf} -Oz -o ${project}.sv.impute.biallelic.vcf.gz
    """
}

process EXTRACT_SAMPLES_ORDER {
    publishDir { out_dir }, mode: 'copy', pattern: "*.txt"
    input:
    path vcf_gz
    val(out_dir)
    val(bcftools)
    output:
    path "samples.order.txt", emit: samples_order
    script:
    """
    ${bcftools} query -l ${vcf_gz} > samples.order.txt
    """
}