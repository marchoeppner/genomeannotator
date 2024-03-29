//
// Check input samplesheet and get read channels
//

include { REPEATMASKER_STAGELIB } from '../../../modules/local/repeatmasker/stagelib/main'
include { REPEATMASKER_REPEATMASK } from '../../../modules/local/repeatmasker/repeatmask/main'
include { FASTASPLITTER } from '../../../modules/local/fastasplitter'
include { CAT_FASTA as REPEATMASKER_CAT_FASTA} from '../../../modules/local/cat/fasta'
include { GUNZIP } from '../../../modules/nf-core/gunzip/main'

ch_versions = Channel.from([])

workflow REPEATMASKER {
    take:
    genome // file path
    rm_lib // file path
    rm_species // tax name
    rm_db // file path

    main:

    FASTASPLITTER(genome,params.npart_size)

    // If chunks == 1, forward - else, map each chunk to the meta hash
    FASTASPLITTER.out.chunks.branch { m,f ->
        single: f.getClass() != ArrayList
        multi: f.getClass() == ArrayList
    }.set { ch_fa_chunks }

    ch_fa_chunks.multi.flatMap { h,fastas ->
        fastas.collect { [ h,file(it)] }
    }.set { ch_chunks_split }

    // We can avoid importing a Dfam database if it is not needed.
    if (params.rm_db && params.rm_species) {
        GUNZIP(
            create_meta_channel(rm_db)
        )
        REPEATMASKER_STAGELIB(
            rm_lib,
            rm_species,
            GUNZIP.out.gunzip.map { m,g -> g }
        )

        ch_versions = ch_versions.mix(REPEATMASKER_STAGELIB.out.versions)

    } else if (params.rm_species) {
        REPEATMASKER_STAGELIB(
            rm_lib,
            params.rm_species,
            file(params.dummy_gff)
        )

        ch_versions = ch_versions.mix(REPEATMASKER_STAGELIB.out.versions)

    } else {
        REPEATMASKER_STAGELIB(
            rm_lib,
            false,
            file(params.dummy_gff)
        )

        ch_versions = ch_versions.mix(REPEATMASKER_STAGELIB.out.versions)

    }

    REPEATMASKER_REPEATMASK(
        ch_fa_chunks.single.map { m,f -> [m,file(f)]}.mix(ch_chunks_split),
        REPEATMASKER_STAGELIB.out.library.collect().map{it[0].toString()},
        rm_lib.collect(),
        rm_species
    )

    ch_versions = ch_versions.mix(REPEATMASKER_REPEATMASK.out.versions)

    REPEATMASKER_CAT_FASTA(REPEATMASKER_REPEATMASK.out.masked.groupTuple())

    ch_versions = ch_versions.mix(REPEATMASKER_CAT_FASTA.out.versions)

    emit:
    fasta = REPEATMASKER_CAT_FASTA.out.fasta
    versions = ch_versions

}


def create_meta_channel(f) {
    def meta = [:]
    meta.id           = file(f).getSimpleName()

    def array = [ meta, f ]

    return array
}

