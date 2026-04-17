process bam_addreplacerg {

    input:
    tuple val(sample_id),
          path(bam)

    output:
    tuple val(sample_id),
          path("${sample_id}.rg.bam")

    script:
    """
    ${params.samtools} addreplacerg \\
        -r ID:${sample_id} -r SM:${sample_id} -r PL:ILLUMINA -r LB:lib1 -r PU:unit1 \\
        -o ${sample_id}.rg.bam ${bam}
    """
}

process bam_sort_by_name {

    input:
    tuple val(sample_id),
          path(rg_bam)

    output:
    tuple val(sample_id),
          path("${sample_id}.qname.bam")

    script:
    """
    ${prams.samtools} sort -n -@ ${task.cpus} -o ${sample_id}.qname.bam ${rg_bam}
    """
}

process bam_fixmate {

    input:
    tuple val(sample_id),
          path(qname_bam)

    output:
    tuple val(sample_id),
          path("${sample_id}.fixmate.bam")

    script:
    """
    ${params.samtools} fixmate -m -@ ${task.cpus} ${qname_bam} ${sample_id}.fixmate.bam
    """
}

process bam_sort_by_pos {

    input:
    tuple val(sample_id),
          path(fixmate_bam)
    val(prefix)

    output:
    tuple val(sample_id),
          path("${sample_id}.pos.bam")

    script:
    """
    ${params.samtools} view -h ${fixmate_bam} | sed -e "s/${prefix}//g" | samtools sort --threads 10 -m 2G -O BAM > ${sample_id}.pos.bam
    """
}

process bam_markdup {

    input:
    tuple val(sample_id),
          path(pos_bam)

    output:
    tuple val(sample_id),
          path("${sample_id}.sort.markdup.bam")

    script:
    """
    ${params.samtools} markdup -@ ${task.cpus} -s ${pos_bam} ${sample_id}.sort.markdup.bam
    """
}

process bam_index {

    input:
    tuple val(sample_id),
          path(markdup_bam)

    output:
    tuple val(sample_id),
          path("${sample_id}.sort.markdup.bam"),
          path("${sample_id}.sort.markdup.bam.bai")

    script:
    """
    ${params.samtools} index ${markdup_bam}
    """
}
