process VG_INDEX {
    cpus ${params.threads}
    input:
        path ref_genome
        path ref_vcf
    output:
        path "Markers.pangenome.dist"
        path "Markers.pangenome.giraffe.gbz"
        path "Markers.pangenome.shortread.withzip.min"
        path "Markers.pangenome.shortread.zipcodes"
    script:
        """
        ${params.vg} autoindex --workflow giraffe -r ${ref_genome} -v ${ref_vcf} -p Markers.pangenome -t ${task.cpus}
        """
}



