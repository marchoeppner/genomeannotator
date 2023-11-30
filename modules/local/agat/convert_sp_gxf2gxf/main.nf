process AGAT_CONVERT_SP_GXF2GXF {

    tag "$meta.id"
    label 'process_low'
    
    conda (params.enable_conda ? "bioconda::agat=1.2.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/agat:1.2.0--pl5321hdfd78af_0':
        'quay.io/biocontainers/agat:1.2.0--pl5321hdfd78af_0' }"

    input:
    tuple val(meta), path(gtf)

    output:
    tuple val(meta), path(gff)    , emit: gff
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    gff = gtf.getBaseName() + ".gff3"
    """
    agat_convert_sp_gxf2gxf.pl -g $gtf -o $gff
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        agat: 1.2.0
    END_VERSIONS
    """
}
