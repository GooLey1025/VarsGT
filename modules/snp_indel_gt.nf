process INDEX_REFERENCE {
    cpus { threads }
    input:
    path ref
    path picard
    val(threads)
    val(samtools)
    val(java)

    output:
    path "${ref.name}.fai", emit: fai
    path "${ref.baseName}.dict", emit: dict

    script:
    """
    ${samtools} faidx ${ref}
    ${java} -jar ${picard} CreateSequenceDictionary R=${ref} O=${ref.baseName}.dict
    """
}

process UNIFIED_GENOTYPER_SNP {
    publishDir { "${out_dir}/snp_indel_genotype" }, mode: 'copy'
    cpus { threads }
    input:
    path ref
    path bam_files
    path fai
    path dict
    path intervals
    path snp_site_vcf
    val(out_dir)
    val(threads)
    val(project)
    val(gatk_java)
    val(gatk_memory)
    path gatk
    output:
    path "${project}.snp.raw.vcf.gz", emit: vcf

    script:
    def bams = bam_files.findAll {it.name.endsWith('.bam')}
    def bam_inputs = bams.collect { "-I ${it}" }.join(' ')
    """    
    ${gatk_java} -Xmx${gatk_memory} -jar ${gatk} \\
        -R ${ref} \\
        -T UnifiedGenotyper \\
        ${bam_inputs} \\
        -glm SNP \\
        -L ${intervals} \\
        -alleles ${snp_site_vcf} \\
        -gt_mode GENOTYPE_GIVEN_ALLELES \\
        --output_mode EMIT_ALL_SITES \\
        -stand_call_conf 30 \\
        -nct ${threads} \\
        -o ${project}.snp.raw.vcf.gz
    """
}

process TABIX_SNP {
    publishDir { "${out_dir}/snp_indel_genotype" }, mode: 'copy'
    cpus { threads }

    input:
    path snp_raw_vcf
    val(out_dir)
    val(threads)
    val(tabix)

    output:
    path "${snp_raw_vcf}", emit: vcf
    path "${snp_raw_vcf}.tbi", emit: tbi

    script:
    """
    ${tabix} -f -p vcf ${snp_raw_vcf}
    """
}

process GATK_SNP_FORMAT {
    publishDir { "${out_dir}/snp_indel_genotype" }, mode: 'copy'
    cpus { threads }

    input:
    path snp_raw_vcf
    path snp_raw_vcf_index
    path snp_site_vcf
    val(out_dir)
    val(threads)
    val(project)
    val(bcftools)
    path assign_id
    val(bgzip)

    output:
    path "${project}.snp.format.id.vcf.gz", emit: vcf
    path "${project}.snp.format.id.vcf.gz.tbi", emit: tbi

    script:
    """
    set -euo pipefail

    tmp_vcf="${project}.snp.altfilled.vcf"

    # header
    ${bcftools} view -h "${snp_raw_vcf}" > "\$tmp_vcf"

    # fill ALT='.' using sites VCF (match by CHROM,POS,REF)
    awk 'BEGIN{FS=OFS="\\t"}
      NR==FNR{
        key=\$1"\\t"\$2"\\t"\$4
        alt[key]=\$5
        next
      }
      {
        key=\$1"\\t"\$2"\\t"\$4
        if(\$5=="." && (key in alt)) \$5=alt[key]
        print
      }' <(${bcftools} view -H "${snp_site_vcf}") <(${bcftools} view -H "${snp_raw_vcf}") >> "\$tmp_vcf"

    bash ${assign_id} SNP \$tmp_vcf > ${project}.snp.format.id.vcf

    # compress + index
    ${bgzip} -@ ${task.cpus} -c "${project}.snp.format.id.vcf" > "${project}.snp.format.id.vcf.gz"
    ${bcftools} index -t --threads ${task.cpus} "${project}.snp.format.id.vcf.gz"
    """
}

process UNIFIED_GENOTYPER_INDEL {
    cpus { threads }
    publishDir { "${out_dir}/snp_indel_genotype" }, mode: 'copy'
    input:
    path ref
    path bam_files
    path fai
    path dict
    path intervals
    path indel_site_vcf
    val(out_dir)
    val(threads)
    val(project)
    val(gatk_java)
    val(gatk_memory)
    path gatk
    output:
    path "${project}.indel.raw.vcf.gz", emit: vcf_gz

    script:
    def bams = bam_files.findAll {it.name.endsWith('.bam')}
    def bam_inputs = bams.collect { "-I ${it}" }.join(' ')
    """    
    ${gatk_java} -Xmx${gatk_memory} -jar ${gatk} \\
        -R ${ref} \\
        -T UnifiedGenotyper \\
        ${bam_inputs} \\
        -glm INDEL \\
        -L ${intervals} \\
        -alleles ${indel_site_vcf} \\
        -gt_mode GENOTYPE_GIVEN_ALLELES \\
        --output_mode EMIT_ALL_SITES \\
        -stand_call_conf 30 \\
        -nct ${threads} \\
        -o ${project}.indel.raw.vcf.gz
    """
}

process TABIX_INDEL {
    publishDir { "${out_dir}/snp_indel_genotype" }, mode: 'copy'
    cpus { threads }

    input:
    path indel_raw_vcf
    val(out_dir)
    val(threads)
    val(tabix)

    output:
    path "${indel_raw_vcf}", emit: vcf_gz
    path "${indel_raw_vcf}.tbi", emit: vcf_gz_index

    script:
    """
    ${tabix} -f -p vcf ${indel_raw_vcf}
    """
}

process GATK_INDEL_FORMAT {
    publishDir { "${out_dir}/snp_indel_genotype" }, mode: 'copy'
    cpus { threads }

    input:
    path indel_raw_vcf
    path indel_raw_vcf_index
    path indel_site_vcf
    val(out_dir)
    val(threads)
    val(project)
    val(bcftools)
    path assign_id
    val(bgzip)

    output:
    path "${project}.indel.format.id.vcf.gz", emit: vcf_gz
    path "${project}.indel.format.id.vcf.gz.tbi", emit: vcf_gz_index
    path "samples.order.txt", emit: samples_order
    script:
    """
    set -euo pipefail

    tmp_vcf="${project}.indel.altfilled.vcf"

    # header
    ${bcftools} view -h "${indel_raw_vcf}" > "\$tmp_vcf"

    # fill ALT='.' using sites VCF (match by CHROM,POS,REF)
    awk 'BEGIN{FS=OFS="\\t"}
      NR==FNR{
        key=\$1"\\t"\$2"\\t"\$4
        alt[key]=\$5
        next
      }
      {
        key=\$1"\\t"\$2"\\t"\$4
        if(\$5=="." && (key in alt)) \$5=alt[key]
        print
      }' <(${bcftools} view -H "${indel_site_vcf}") <(${bcftools} view -H "${indel_raw_vcf}") >> "\$tmp_vcf"

    bash ${assign_id} INDEL \$tmp_vcf > ${project}.indel.format.id.vcf

    # compress + index
    ${bgzip} -@ ${task.cpus} -c "${project}.indel.format.id.vcf" > "${project}.indel.format.id.vcf.gz"
    ${bcftools} index -t --threads ${task.cpus} "${project}.indel.format.id.vcf.gz"
    ${bcftools} query -l ${project}.indel.format.id.vcf.gz > samples.order.txt
    """
}


