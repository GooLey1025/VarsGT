process bam_addreplacerg {
    cpus "${params.bam_per_task_threads}"
    memory "${params.bam_per_task_memory}"
    maxForks "${params.bam_max_parallel_num}"

    input:
    tuple val(sample_id),
          path(bam)

    output:
    tuple val(sample_id),
          path("${sample_id}.rg.bam")

    script:
    """
    ${params.samtools} addreplacerg \\
        -r ID:${sample_id} -r SM:${sample_id} -r PL:ILLUMINA -r LB:lib1 -r PU:unit1 -@ ${task.cpus} \\
        -o ${sample_id}.rg.bam ${bam}
    """
}

process bam_sort_by_name {
    cpus "${params.bam_per_task_threads}"
    memory "${params.bam_per_task_memory}"
    maxForks "${params.bam_max_parallel_num}"

    input:
    tuple val(sample_id),
          path(rg_bam)

    output:
    tuple val(sample_id),
          path("${sample_id}.qname.bam")

    script:
    """
    ${params.samtools} sort -n -@ ${task.cpus} -o ${sample_id}.qname.bam ${rg_bam}
    """
}

process bam_fixmate {
    cpus "${params.bam_per_task_threads}"
    memory "${params.bam_per_task_memory}"
    maxForks "${params.bam_max_parallel_num}"

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
    cpus "${params.bam_per_task_threads}"
    memory "${params.bam_per_task_memory}"
    maxForks "${params.bam_max_parallel_num}"

    input:
    tuple val(sample_id),
          path(fixmate_bam)
    val(prefix)

    output:
    tuple val(sample_id),
          path("${sample_id}.pos.bam")

    script:
    """
    ${params.samtools} view -h ${fixmate_bam} -@ ${task.cpus} | sed -e "s/${prefix}//g" | ${params.samtools} sort --threads ${task.cpus} -O BAM > ${sample_id}.pos.bam
    """
}

process bam_markdup {
    cpus "${params.bam_per_task_threads}"
    memory "${params.bam_per_task_memory}"
    maxForks "${params.bam_max_parallel_num}"

    input:
    tuple val(sample_id),
          path(pos_bam)
    val(mark_duplicates)

    output:
    tuple val(sample_id),
          path("${sample_id}.sort.rg.markdup.bam")

    script:
    def remove_option = mark_duplicates ? "" : "-r"
    """
    ${params.samtools} markdup -@ ${task.cpus} -s ${remove_option} ${pos_bam} ${sample_id}.sort.rg.markdup.bam
    """
}

process bam_index {
    cpus "${params.bam_per_task_threads}"
    memory "${params.bam_per_task_memory}"
    maxForks "${params.bam_max_parallel_num}"
    publishDir "${params.out_dir}/bam", mode: 'copy'


    input:
    tuple val(sample_id),
          path(markdup_bam)

    output:
    tuple val(sample_id),
          path("${sample_id}.sort.rg.markdup.bam"),
          path("${sample_id}.sort.rg.markdup.bam.bai")

    script:
    """
    ${params.samtools} index -@ ${task.cpus} ${markdup_bam}
    """
}

process bam_index_existing {
    cpus "${params.bam_per_task_threads}"
    memory "${params.bam_per_task_memory}"
    maxForks "${params.bam_max_parallel_num}"
    publishDir "${params.out_dir}/bam", mode: 'copy'

    input:
    tuple val(sample_id),
          path(input_bam)

    output:
    tuple val(sample_id),
          path("${input_bam}"),
          path("${input_bam}.bai")

    script:
    """
    ${params.samtools} index -@ ${task.cpus} ${input_bam}
    """
}
