def kmc_mem = (params.kmc_memory_per_task =~ /(\d+)/)[0][1]

process kmc_kmer {
    cpus "${params.kmc_cpus_per_task}"
    memory "${params.kmc_memory_per_task}"
    maxForks "${params.kmc_max_parallel_number}"
    input:
    tuple val(sample_id), path(fq_1), path(fq_2)
    output:
    tuple val(sample_id), path("${sample_id}.kff")
    script:
    """
    TMPDIR="\$PWD/tmp_kmc"
    mkdir -p \$TMPDIR
    > fq.list
    echo "${fq_1}" >> fq.list
    echo "${fq_2}" >> fq.list
    ${params.kmc} -k29 -m${kmc_mem} -sm -okff -t${task.cpus} -hp @fq.list ${sample_id} \${TMPDIR}
    """
}

process giraffe_mapping {
    cpus "${params.giraffe_mapping_cpus_per_task}"
    memory "${params.giraffe_mapping_memory_per_task}"
    publishDir "${params.out_dir}/bam", mode: 'copy'
    maxForks "${params.giraffe_mapping_parallel_number}"
    
    input:
    tuple val(sample_id),
          path(fq_1),
          path(fq_2),
          path(gbz),
          path(hapl),
          path(sample_kmer),
          val(ref_path)

    output:
    tuple val(sample_id), path("${sample_id}.bam")

    script:
    def ref_paths_option = ref_path ? "--ref-paths ${ref_path}" : ""
    """
    ${params.vg} giraffe -p -t ${task.cpus} -Z ${gbz} --haplotype-name ${hapl} --kff-name ${sample_kmer} \
        -N ${sample_id} -f ${fq_1} -f ${fq_2} ${ref_paths_option} -o BAM > ${sample_id}.bam
    """
}
