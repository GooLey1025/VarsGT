process CONCAT_SNP_INDEL {
    publishDir params.out_dir, mode: 'copy', pattern: "*.vcf.gz"
    input:
    path snp_vcf_gz
    path snp_vcf_gz_index
    path indel_vcf_gz
    path indel_vcf_gz_index
    output:
    path "${params.project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${params.project}.snp.indel.sv.biallelic.vcf.gz"
    path "${params.project}.snp.biallelic.vcf.gz", emit: snp_biallelic_vcf
    path "${params.project}.indel.biallelic.vcf.gz", emit: indel_biallelic_vcf
    path "${params.project}.sv.biallelic.vcf.gz", emit: sv_biallelic_vcf
    script:
    """
    ${params.bcftools} concat -a ${snp_vcf_gz} ${indel_vcf_gz} -o ${params.project}.snp.indel.sv.vcf.gz
    ${params.bcftools} norm -m -both ${params.project}.snp.indel.sv.vcf.gz -o ${params.project}.snp.indel.sv.biallelic.vcf.gz
    ${params.bcftools} view -i 'ID ~ "^SNP-"' ${params.project}.snp.indel.sv.biallelic.vcf.gz -o ${params.project}.snp.biallelic.vcf.gz
    ${params.bcftools} view -i 'ID ~ "^INDEL-"' ${params.project}.snp.indel.sv.biallelic.vcf.gz -o ${params.project}.indel.biallelic.vcf.gz
    touch ${params.project}.sv.biallelic.vcf.gz
    """
}

process CONCAT_SNP_SV {
    publishDir params.out_dir, mode: 'copy', pattern: "*.vcf.gz"
    input:
    path snp_vcf_gz
    path snp_vcf_gz_index
    path sv_vcf_gz
    path sv_vcf_gz_index
    output:
    path "${params.project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${params.project}.snp.indel.sv.biallelic.vcf.gz"
    path "${params.project}.snp.biallelic.vcf.gz", emit: snp_biallelic_vcf
    path "${params.project}.indel.biallelic.vcf.gz", emit: indel_biallelic_vcf
    path "${params.project}.sv.biallelic.vcf.gz", emit: sv_biallelic_vcf
    script:
    """
    ${params.bcftools} concat -a ${snp_vcf_gz} ${sv_vcf_gz} -o ${params.project}.snp.indel.sv.vcf.gz
    ${params.bcftools} norm -m -both ${params.project}.snp.indel.sv.vcf.gz -o ${params.project}.snp.indel.sv.biallelic.vcf.gz
    ${params.bcftools} view -i 'ID ~ "^SNP-"' ${params.project}.snp.indel.sv.biallelic.vcf.gz -o ${params.project}.snp.biallelic.vcf.gz
    ${params.bcftools} view -i 'ID ~ "^SV-"' ${params.project}.snp.indel.sv.biallelic.vcf.gz -o ${params.project}.sv.biallelic.vcf.gz
    touch ${params.project}.indel.biallelic.vcf.gz
    """
}

process CONCAT_INDEL_SV {
    publishDir params.out_dir, mode: 'copy', pattern: "*.vcf.gz"
    input:
    path indel_vcf_gz
    path indel_vcf_gz_index
    path sv_vcf_gz
    path sv_vcf_gz_index
    output:
    path "${params.project}.snp.indel.sv.vcf.gz", emit: snp_indel_sv_vcf
    path "${params.project}.snp.indel.sv.biallelic.vcf.gz"
    path "${params.project}.snp.biallelic.vcf.gz", emit: snp_biallelic_vcf
    path "${params.project}.indel.biallelic.vcf.gz", emit: indel_biallelic_vcf
    path "${params.project}.sv.biallelic.vcf.gz", emit: sv_biallelic_vcf
    script:
    """
    ${params.bcftools} concat -a ${indel_vcf_gz} ${sv_vcf_gz} -o ${params.project}.snp.indel.sv.vcf.gz
    ${params.bcftools} norm -m -both ${params.project}.snp.indel.sv.vcf.gz -o ${params.project}.snp.indel.sv.biallelic.vcf.gz
    ${params.bcftools} view -i 'ID ~ "^INDEL-"' ${params.project}.snp.indel.sv.biallelic.vcf.gz -o ${params.project}.indel.biallelic.vcf.gz
    ${params.bcftools} view -i 'ID ~ "^SV-"' ${params.project}.snp.indel.sv.biallelic.vcf.gz -o ${params.project}.sv.biallelic.vcf.gz
    touch ${params.project}.snp.biallelic.vcf.gz
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
    path "${params.project}.snp.indel.sv.biallelic.vcf.gz"
    path "${params.project}.snp.biallelic.vcf.gz", emit: snp_biallelic_vcf
    path "${params.project}.indel.biallelic.vcf.gz", emit: indel_biallelic_vcf
    path "${params.project}.sv.biallelic.vcf.gz", emit: sv_biallelic_vcf
    script:
    """
    ${params.bcftools} concat -a ${snp_vcf_gz} ${indel_vcf_gz} ${sv_vcf_gz} -o ${params.project}.snp.indel.sv.vcf.gz
    ${params.bcftools} norm -m -both ${params.project}.snp.indel.sv.vcf.gz -o ${params.project}.snp.indel.sv.biallelic.vcf.gz
    ${params.bcftools} view -i 'ID ~ "^SNP-"' ${params.project}.snp.indel.sv.biallelic.vcf.gz -o ${params.project}.snp.biallelic.vcf.gz
    ${params.bcftools} view -i 'ID ~ "^INDEL-"' ${params.project}.snp.indel.sv.biallelic.vcf.gz -o ${params.project}.indel.biallelic.vcf.gz
    ${params.bcftools} view -i 'ID ~ "^SV-"' ${params.project}.snp.indel.sv.biallelic.vcf.gz -o ${params.project}.sv.biallelic.vcf.gz
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


    bgzip \$(basename ${input_vcf} .vcf.gz).impute.vcf.gz -d -c > \$(basename ${input_vcf} .vcf.gz).impute.vcf
    ${params.bcftools} reheader -h header.tmp \$(basename ${input_vcf} .vcf.gz).impute.vcf > \$(basename ${input_vcf} .vcf.gz).impute.reheader.vcf 
    ${params.bcftools} norm -m -both \$(basename ${input_vcf} .vcf.gz).impute.reheader.vcf -o \$(basename ${input_vcf} .vcf.gz).impute.biallelic.vcf.gz
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
    ${params.bcftools} view -i 'ID ~ "^SNP-"' ${snp_indel_sv_impute_biallelic_vcf} -o ${params.project}.snp.impute.biallelic.vcf.gz
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
    ${params.bcftools} view -i 'ID ~ "^INDEL-"' ${snp_indel_sv_impute_biallelic_vcf} -o ${params.project}.indel.impute.biallelic.vcf.gz
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