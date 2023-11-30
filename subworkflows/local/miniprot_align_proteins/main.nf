//
// Check input samplesheet and get read channels
//

include { GAAS_FASTACLEANER } from '../../../modules/local/gaas/fastacleaner/main'
include { EXONERATE_FASTACLEAN } from '../../../modules/local/exonerate/fastaclean/main'
include { GAAS_FASTAFILTERBYSIZE } from '../../../modules/local/gaas/fastafilterbysize/main'
include { MINIPROT_INDEX } from '../../../modules/local/miniprot/index/main'
include { MINIPROT_ALIGN } from '../../../modules/local/miniprot/align/main'
include { AUGUSTUS_ALIGNTOHINTS_V2 } from '../../../modules/local/augustus/aligntohints_v2/main'
include { AGAT_CONVERT_SP_GXF2GXF } from '../../../modules/local/agat/convert_sp_gxf2gxf/main'

ch_versions = Channel.from([])

workflow MINIPROT_ALIGN_PROTEIN {

    take:
    genome // file path
    proteins // file path

    main:

        // Initial cleaning of protein fasta file
        GAAS_FASTACLEANER(
            create_fasta_channel(proteins)
        )
        
        ch_versions = ch_versions.mix(GAAS_FASTACLEANER.out.versions)
        
        // and some more cleaning (could write a new, combined tool for this...)
        EXONERATE_FASTACLEAN(
            GAAS_FASTACLEANER.out.fasta
        )
        
        ch_versions = ch_versions.mix(EXONERATE_FASTACLEAN.out.versions)
        
        // Remove sequences short than specified
        GAAS_FASTAFILTERBYSIZE(
            EXONERATE_FASTACLEAN.out.fasta,
            params.min_prot_length
        )
        
        ch_versions = ch_versions.mix(GAAS_FASTAFILTERBYSIZE.out.versions)
        
        // Build the miniprot index from genome fasta
        MINIPROT_INDEX(
            genome
        )
        
        ch_versions = ch_versions.mix(MINIPROT_INDEX.out.versions)

        // Splot protein fasta into chunks for parallel processing
        ch_fasta_chunks = GAAS_FASTAFILTERBYSIZE.out.fasta.splitFasta(by: params.nproteins, file: true, elem: [1])

        // Run alignment
        MINIPROT_ALIGN(
            MINIPROT_INDEX.out.index.collect(),
            ch_fasta_chunks,
        )
        
        ch_versions = ch_versions.mix(MINIPROT_ALIGN.out.versions)
        
        // group miniprot alignments by name of protein fasta file and make a combined result
        miniprot_align = MINIPROT_ALIGN.out.align.groupTuple().collectFile() { m,f -> 
            [ "${m.id}.miniprot.gtf", f + "\n" ] 
        }

        // Convert miniprot result to hints
        AUGUSTUS_ALIGNTOHINTS_V2(
            miniprot_align,
            "miniprot",
            params.max_intron_size,
            params.pri_prot
        )
        
        ch_versions = ch_versions.mix(AUGUSTUS_ALIGNTOHINTS_V2.out.versions)
        
        AGAT_CONVERT_SP_GXF2GXF(
            miniprot_align
        )
        
        ch_versions = ch_versions.mix(AGAT_CONVERT_SP_GXF2GXF.out.versions)

    emit:
        hints = AUGUSTUS_ALIGNTOHINTS_V2.out.gff
        gff = AGAT_CONVERT_SP_GXF2GXF.out.gff
        gff_training = AGAT_CONVERT_SP_GXF2GXF.out.gff
        evm = AGAT_CONVERT_SP_GXF2GXF.out.gff
        versions = ch_versions

}

def create_fasta_channel(fasta) {
    def meta = [:]
    meta.id           = file(fasta).getSimpleName()

    def array = [ meta, fasta ]

    return array
}

