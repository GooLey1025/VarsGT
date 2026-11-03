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

process PREPARE_SNP_INDEL_SITES {
    publishDir { "${out_dir}/snp_indel_genotype" }, mode: 'copy'
    cpus { threads }
    input:
    path site_vcfs
    val(out_dir)
    val(threads)
    val(project)
    val(bcftools)
    output:
    path "${project}.snp_indel.sites.vcf.gz", emit: sites_vcf
    path "${project}.snp_indel.sites.vcf.gz.tbi", emit: sites_vcf_index

    script:
    def sites = site_vcfs instanceof List ? site_vcfs : [site_vcfs]
    def first_site = sites[0].toString()
    def record_commands = sites.collect { site ->
        "${bcftools} view -H ${site}"
    }.join('\n')
    """
    set -euo pipefail

    # Accept both ordinary .vcf and bgzip-compressed .vcf.gz inputs. Using
    # `bcftools view` avoids the indexed/bgzip input requirement of concat.
    ${bcftools} view -h ${first_site} > ${project}.snp_indel.unsorted.vcf
    {
    ${record_commands}
    } >> ${project}.snp_indel.unsorted.vcf
    ${bcftools} sort -Oz -o ${project}.snp_indel.sites.vcf.gz \\
        ${project}.snp_indel.unsorted.vcf
    ${bcftools} index -t -f ${project}.snp_indel.sites.vcf.gz
    """
}

process HAPLOTYPE_CALLER_SNP_INDEL {
    publishDir { "${out_dir}/sample_genotype" }, mode: 'copy'
    cpus { threads }
    input:
    tuple val(sample_id), path(bam), path(bai)
    path ref
    path fai
    path dict
    path sites_vcf
    path sites_vcf_index
    val(out_dir)
    val(threads)
    val(java)
    val(gatk_memory)
    path gatk
    val(padding)
    val(tabix)
    output:
    tuple val(sample_id), path("${sample_id}.snp_indel.raw.vcf.gz"), path("${sample_id}.snp_indel.raw.vcf.gz.tbi"), emit: vcf

    script:
    """
    set -euo pipefail
    ${java} -Xmx${gatk_memory} -jar ${gatk} HaplotypeCaller \\
        -R ${ref} \\
        -I ${bam} \\
        -L ${sites_vcf} \\
        --alleles ${sites_vcf} \\
        -ip ${padding} \\
        --native-pair-hmm-threads ${threads} \\
        -O ${sample_id}.snp_indel.raw.vcf.gz
    ${tabix} -f -p vcf ${sample_id}.snp_indel.raw.vcf.gz
    """
}

process FILL_MISSING_SNP_INDEL_SITES {
    publishDir { "${out_dir}/sample_genotype" }, mode: 'copy'
    cpus { threads }
    input:
    tuple val(sample_id), path(raw_vcf), path(raw_vcf_index)
    path sites_vcf
    path sites_vcf_index
    val(out_dir)
    val(threads)
    val(bcftools)
    val(bgzip)
    output:
    tuple val(sample_id), path("${sample_id}.snp_indel.complete.vcf.gz"), path("${sample_id}.snp_indel.complete.vcf.gz.tbi"), emit: vcf

    script:
    """
    set -euo pipefail

    ${bcftools} view -h "${raw_vcf}" > missing_sites.vcf
    ${bcftools} view -T ^"${raw_vcf}" -H "${sites_vcf}" | \\
      awk 'BEGIN { FS=OFS="\\t" }
        { print \$1,\$2,\$3,\$4,\$5,".",".",".","GT","./." }' >> missing_sites.vcf
    ${bgzip} -@ ${task.cpus} -c missing_sites.vcf > missing_sites.vcf.gz
    ${bcftools} index -t missing_sites.vcf.gz

    ${bcftools} concat -a -Ou "${raw_vcf}" missing_sites.vcf.gz | \\
      ${bcftools} sort -Oz -o ${sample_id}.snp_indel.complete.vcf.gz
    ${bcftools} index -t ${sample_id}.snp_indel.complete.vcf.gz
    """
}

process MERGE_AND_FORMAT_SNP_INDEL {
    publishDir { "${out_dir}/snp_indel_genotype" }, mode: 'copy'
    cpus { threads }
    input:
    path sample_vcf_files
    val(out_dir)
    val(threads)
    val(project)
    val(bcftools)
    val(bgzip)
    output:
    path "${project}.snp_indel.format.id.vcf.gz", emit: vcf
    path "${project}.snp_indel.format.id.vcf.gz.tbi", emit: tbi
    path "samples.order.txt", emit: samples_order

    script:
    def vcfs = sample_vcf_files.findAll { it.name.endsWith('.vcf.gz') }
    def vcf_inputs = vcfs.collect { it.toString() }.join(' ')
    """
    set -euo pipefail

    ${bcftools} merge --force-samples -Ou ${vcf_inputs} | \\
      ${bcftools} sort -Ov -o ${project}.snp_indel.complete.vcf

    ${bcftools} view -h ${project}.snp_indel.complete.vcf > ${project}.snp_indel.format.id.vcf
    ${bcftools} view -H ${project}.snp_indel.complete.vcf | \\
      awk 'BEGIN { FS=OFS="\\t" }
        {
          n=split(\$5, alts, ",")
          is_snp=(length(\$4)==1)
          for (i=1; i<=n; i++) {
            if (length(alts[i]) != 1) {
              is_snp=0
            }
          }
          type=(is_snp ? "SNP" : "INDEL")
          key=type"-"\$1"-"\$2
          count[key]++
          \$3=key"-"count[key]
          print
        }' >> ${project}.snp_indel.format.id.vcf

    ${bgzip} -@ ${task.cpus} -c ${project}.snp_indel.format.id.vcf > ${project}.snp_indel.format.id.vcf.gz
    ${bcftools} index -t --threads ${task.cpus} ${project}.snp_indel.format.id.vcf.gz
    ${bcftools} query -l ${project}.snp_indel.format.id.vcf.gz > samples.order.txt
    """
}


