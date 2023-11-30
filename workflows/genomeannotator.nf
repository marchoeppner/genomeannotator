/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowGenomeannotator.initialise(params, log)

def checkPathParamList = [ params.multiqc_config, params.assembly ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.assembly) { ch_genome = file(params.assembly, checkIfExists: true) } else { exit 1, 'No assembly specified!' }

// Set relevant input channels
// Most of these are meant to be single files; this is because of potential ID collissions that can arise from merging multiple files later on.
// To enable multiple files, some kind of sanity check is required that can independently resolve such conflicts. TBD.
if (params.proteins) { ch_proteins = file(params.proteins, checkIfExists: true) } else { ch_proteins = Channel.empty() }
if (params.proteins_targeted) { ch_proteins_targeted = file(params.proteins_targeted, checkIfExists: true) } else { ch_proteins_targeted = Channel.empty() }
if (params.transcripts) { ch_t = file(params.transcripts, checkIfExists:true) } else { ch_t = Channel.empty() }
if (params.rnaseq_samples) { ch_samplesheet = file(params.rnaseq_samples, checkIfExists: true) } else { ch_samplesheet = Channel.empty() }
if (params.rm_lib) { ch_repeats = Channel.fromPath(file(params.rm_lib, checkIfExists: true)) } else { ch_repeats = Channel.fromPath("${workflow.projectDir}/assets/repeatmasker/repeats.fa") }
if (params.references) { ch_ref_genomes = Channel.fromPath(params.references, checkIfExists: true)  } else { ch_ref_genomes = Channel.empty() }
if (params.rm_db && params.rm_species)  { ch_rm_db = file(params.rm_db) } else { ch_rm_db = Channel.empty() }
if (params.aug_config_dir) { ch_aug_config_folder = file(params.aug_config_dir, checkIfExists: true) } else { ch_aug_config_folder = Channel.empty() }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()

ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

ch_aug_extrinsic_cfg = params.aug_extrinsic_cfg ? Channel.from( file(params.aug_extrinsic_cfg, checkIfExists: true) ) : Channel.from( file("${workflow.projectDir}/assets/augustus/augustus_default.cfg"))
ch_evm_weights = Channel.from(file(params.evm_weights, checkIfExists: true))
ch_rfam_cm = file("${workflow.projectDir}/assets/rfam/14.2/Rfam.cm.gz", checkIfExists: true)
ch_rfam_family = file("${workflow.projectDir}/assets/rfam/14.2/family.txt.gz", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//

include { ASSEMBLY_PREPROCESS }                       from '../subworkflows/local/assembly_preprocess/main'
include { REPEATMASKER }                              from '../subworkflows/local/repeatmasker/main'
include { SPALN_ALIGN_PROTEIN ; SPALN_ALIGN_PROTEIN as SPALN_ALIGN_MODELS } from '../subworkflows/local/spaln_align_protein/main'
include { RNASEQ_ALIGN }                              from '../subworkflows/local/rnaseq_align/main'
include { MINIMAP_ALIGN_TRANSCRIPTS ; MINIMAP_ALIGN_TRANSCRIPTS as TRINITY_ALIGN_TRANSCRIPTS } from '../subworkflows/local/minimap_align_transcripts/main'
include { AUGUSTUS_PIPELINE }                         from '../subworkflows/local/augustus_pipeline/main'
include { PASA_PIPELINE }                             from '../subworkflows/local/pasa_pipeline/main'
include { GENOME_ALIGN }                              from '../subworkflows/local/genome_align/main'
include { EVM }                                       from '../subworkflows/local/evm/main'
include { FASTA_PREPROCESS as TRANSCRIPT_PREPROCESS } from '../subworkflows/local/fasta_preprocess/main'
include { BUSCO_QC }                                  from '../subworkflows/local/busco_qc/main'
include { NCRNA }                                     from '../subworkflows/local/ncrna/main'
include { EGGNOG_MAPPER }                             from '../subworkflows/local/eggnog_mapper/main'
include { MINIPROT_ALIGN_PROTEIN }                    from '../subworkflows/local/miniprot_align_proteins/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//

include { SAMTOOLS_MERGE }                           from '../modules/local/samtools/merge/main'
include { MULTIQC }                                  from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS }              from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { TRINITY_GENOMEGUIDED }                     from '../modules/local/trinity/genomeguided/main'
include { AUGUSTUS_BAM2HINTS }                       from '../modules/local/augustus/bam2hints/main'
include { AUGUSTUS_FINDCONFIG }                      from '../modules/local/augustus/findconfig/main'
include { REPEATMODELER }                            from '../modules/local/repeatmodeler'
include { AUGUSTUS_STAGECONFIG }                     from '../modules/local/augustus/stageconfig/main'
include { AUGUSTUS_TRAINING }                        from '../modules/local/augustus/training/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow GENOMEANNOTATOR {

    ch_empty_gff        = Channel.fromPath(params.dummy_gff)
    ch_versions         = Channel.empty()
    ch_hints            = Channel.empty()
    ch_repeats_lib      = Channel.empty()
    ch_proteins_gff     = Channel.from([])
    ch_transcripts_gff  = Channel.from([])
    ch_genes_gff        = Channel.empty()
    ch_transcripts      = Channel.empty()
    ch_genome_rm        = Channel.empty()
    ch_proteins_fa      = Channel.empty()
    ch_busco_qc         = Channel.empty()
    ch_training_genes   = Channel.empty()
    ch_func_annot       = Channel.from([])

    //
    // SUBWORKFLOW: Turn transcript inputs to channel
    //
    if (params.transcripts) {
        TRANSCRIPT_PREPROCESS(
            ch_t
        )
        ch_transcripts = ch_transcripts.mix(TRANSCRIPT_PREPROCESS.out.fasta)
    }

    //
    // MODULE: Find the default Augustus config dir if none is provided.
    //
    if (!params.aug_config_dir) {
        AUGUSTUS_FINDCONFIG(ch_empty_gff)
        ch_aug_config_folder = AUGUSTUS_FINDCONFIG.out.config
    } else {
        ch_aug_config_folder = Channel.fromPath(file(params.aug_config_dir))
    }
    //
    // MODULE: Stage Augustus config dir to be editable
    //
    AUGUSTUS_STAGECONFIG(ch_aug_config_folder)
    ch_aug_config_folder = AUGUSTUS_STAGECONFIG.out.config_dir

    //
    // SUBWORKFLOW: Validate and pre-process the assembly
    //
    ASSEMBLY_PREPROCESS(
        ch_genome
    )
    ch_versions = ch_versions.mix(ASSEMBLY_PREPROCESS.out.versions)

    //
    // SUBWORKFLOW: Search for ncRNAs
    //
    if (params.ncrna) {
        NCRNA(
            ASSEMBLY_PREPROCESS.out.fasta,
            ch_rfam_cm,
            ch_rfam_family
        )
    }

    //
    // SUBWORKFLOW: Align genomes and map annotations
    //
    if (params.references) {
        GENOME_ALIGN(
            ASSEMBLY_PREPROCESS.out.fasta,
            ch_ref_genomes
        )
        ch_versions = ch_versions.mix(GENOME_ALIGN.out.versions)
        ch_hints = ch_hints.mix(GENOME_ALIGN.out.hints)
        ch_genes_gff = ch_genes_gff.mix(GENOME_ALIGN.out.gff)
    }

    //
    // SUBWORKFLOW: Repeat modelling if no repeats are provided
    //
    if (!params.rm_lib && !params.rm_species) {
        REPEATMODELER(
            ASSEMBLY_PREPROCESS.out.fasta
        )
        ch_repeats = REPEATMODELER.out.fasta.map {m,fasta -> fasta}
    }

    //
    // MODULE: Repeatmask the genome; if a repeat species is provided, use that - else the repeats in FASTA format
    if (params.rm_species) {
        REPEATMASKER(
            ASSEMBLY_PREPROCESS.out.fasta,
            ch_repeats,
            params.rm_species,
            ch_rm_db
        )
        ch_versions = ch_versions.mix(REPEATMASKER.out.versions)
        ch_genome_rm = REPEATMASKER.out.fasta
    } else {
        REPEATMASKER(
            ASSEMBLY_PREPROCESS.out.fasta,
            ch_repeats,
            false,
            ch_rm_db
        )
        ch_versions = ch_versions.mix(REPEATMASKER.out.versions)
        ch_genome_rm = REPEATMASKER.out.fasta
    }

    //
    // SUBWORKFLOW: Align proteins from related organisms with SPALN

    if (params.proteins) {
        SPALN_ALIGN_PROTEIN(
            ASSEMBLY_PREPROCESS.out.fasta.collect(),
            ch_proteins,
            params.spaln_protein_id
        )
        ch_versions = ch_versions.mix(SPALN_ALIGN_PROTEIN.out.versions)
        ch_hints = ch_hints.mix(SPALN_ALIGN_PROTEIN.out.hints)
        ch_proteins_gff = ch_proteins_gff.mix(SPALN_ALIGN_PROTEIN.out.evm)
    }

    //
    // SUBWORKFLOW: Align species-specific proteins
    if (params.proteins_targeted) {
        MINIPROT_ALIGN_PROTEIN(
            ASSEMBLY_PREPROCESS.out.fasta,
            ch_proteins_targeted,
        )
        ch_versions = ch_versions.mix(MINIPROT_ALIGN_PROTEIN.out.versions)
        ch_hints = ch_hints.mix(MINIPROT_ALIGN_PROTEIN.out.hints)
        ch_genes_gff = ch_genes_gff.mix(MINIPROT_ALIGN_PROTEIN.out.gff)
        ch_training_genes = MINIPROT_ALIGN_PROTEIN.out.gff_training
    }

    //
    // SUBWORKFLOW: Align RNAseq reads
    //
    if (params.rnaseq_samples) {
        RNASEQ_ALIGN(
            ASSEMBLY_PREPROCESS.out.fasta.collect(),
            ch_samplesheet
        )
       //
       // MODULE: Merge all BAM files
       //
        RNASEQ_ALIGN.out.bam.map{ meta, bam ->
        new_meta = [:]
        new_meta.id = meta.ref
        tuple(new_meta,bam)
        }.groupTuple(by:[0])
        .set{bam_mapped}

       //
       // MODULE: Merge BAM files
       //
        SAMTOOLS_MERGE(
            bam_mapped
        )
        AUGUSTUS_BAM2HINTS(
            SAMTOOLS_MERGE.out.bam,
            params.pri_rnaseq
        )
        ch_hints = ch_hints.mix(AUGUSTUS_BAM2HINTS.out.gff)
        ch_versions = ch_versions.mix(RNASEQ_ALIGN.out.versions.first(),AUGUSTUS_BAM2HINTS.out.versions,SAMTOOLS_MERGE.out.versions)

       //
       // SUBWORKFLOW: Assemble transcripts using Trinity and align to genome
       //
        if (params.trinity) {
            TRINITY_GENOMEGUIDED(
                SAMTOOLS_MERGE.out.bam,
                params.max_intron_size
            )
            ch_transcripts = ch_transcripts.mix(TRINITY_GENOMEGUIDED.out.fasta)
            ch_versions = ch_versions.mix(TRINITY_GENOMEGUIDED.out.versions)
        }
    }

    //
    // SUBWORKFLOW: Align transcripts to the genome
    //

    if (params.transcripts || params.trinity) {
        MINIMAP_ALIGN_TRANSCRIPTS(
            ASSEMBLY_PREPROCESS.out.fasta.collect(),
            ch_transcripts
        )
        ch_versions = ch_versions.mix(MINIMAP_ALIGN_TRANSCRIPTS.out.versions)
        ch_transcripts_gff = ch_transcripts_gff.mix(MINIMAP_ALIGN_TRANSCRIPTS.out.gff)
        ch_hints = ch_hints.mix(MINIMAP_ALIGN_TRANSCRIPTS.out.hints)
    }

    //
    // SUBWORKFLOW: Assemble transcripts into gene models
    //
    if (params.pasa) {
        PASA_PIPELINE(
            ASSEMBLY_PREPROCESS.out.fasta,
            ch_transcripts.map { m,t -> t }.collectFile(name: "transcripts.merged.fa").map { it ->
                def mmeta = [:]
                mmeta.id = "merged_transcripts"
                tuple(mmeta,it)
            }
        )
        ch_versions = ch_versions.mix(PASA_PIPELINE.out.versions)
        ch_genes_gff = ch_genes_gff.mix(PASA_PIPELINE.out.gff)
        ch_training_genes =  PASA_PIPELINE.out.gff_training
        ch_proteins_fa = PASA_PIPELINE.out.proteins
    }

    //
    // SUBWORKFLOW: Train augustus prediction model
    //
    if (params.aug_training) {

        if (params.proteins_targeted) {
            AUGUSTUS_TRAINING(
                ch_training_genes.collect(),
                REPEATMASKER.out.fasta,
                ch_aug_config_folder.collect().map {it[0].toString() },
                ch_aug_config_folder,
                params.aug_species
            )
            ch_aug_config_final = AUGUSTUS_TRAINING.out.aug_config_dir
        } else if (params.pasa) {
            AUGUSTUS_TRAINING(
                ch_training_genes.collect(),
                REPEATMASKER.out.fasta.collect(),
                ch_aug_config_folder.collect().map {it[0].toString() },
                ch_aug_config_folder,
                params.aug_species
            )
            ch_aug_config_final = AUGUSTUS_TRAINING.out.aug_config_dir
        }

    } else {
        ch_aug_config_final = ch_aug_config_folder
    }

    //
    // SUBWORKFLOW: Predict gene models using AUGUSTUS
    //
    all_hints = ch_hints.unique().collectFile(name: 'hints.gff')

    AUGUSTUS_PIPELINE(
        REPEATMASKER.out.fasta,
        all_hints,
        ch_aug_config_final,
        ch_aug_extrinsic_cfg,
    )
    ch_versions = ch_versions.mix(AUGUSTUS_PIPELINE.out.versions)
    ch_genes_gff = ch_genes_gff.mix(AUGUSTUS_PIPELINE.out.gff)
    ch_proteins_fa = ch_proteins_fa.mix(AUGUSTUS_PIPELINE.out.proteins)
    //ch_func_annot = ch_func_annot.mix(AUGUSTUS_PIPELINE.out.func_annot)

    //
    // SUBWORKFLOW: Consensus gene building with EVM
    //
    if (params.evm) {
        EVM(
            ch_genome_rm,
            ch_genes_gff.map{m,g -> g}.collectFile(name: 'genes.gff3'),
            ch_proteins_gff.map{m,p -> p}.mix(ch_empty_gff).collectFile(name: 'proteins.gff3'),
            ch_transcripts_gff.map{m,t ->t}.mix(ch_empty_gff).collectFile(name: 'transcripts.gff3'),
            ch_evm_weights
        )
        ch_proteins_fa = ch_proteins_fa.mix(EVM.out.proteins)
        ch_func_annot = ch_func_annot.mix(EVM.out.func_annot)

        ch_versions = ch_versions.mix(EVM.out.versions)

    }

    //
    // SUBWORKFLOW: Check proteome completeness with BUSCO
    //
    if (params.busco_lineage) {
        BUSCO_QC(
            ch_proteins_fa,
            params.busco_lineage,
            params.busco_db_path
        )
        ch_busco_qc = BUSCO_QC.out.busco_summary

        ch_versions = ch_versions.mix(BUSCO_QC.out.versions)

    }

    //
    // SUBWORKFLOW: Functional annotation using Eggnog_mapper
    //
    if (params.eggnog_mapper_db || params.eggnog_taxonomy) {

        EGGNOG_MAPPER(
            ch_func_annot
        )

        ch_versions = ch_versions.mix(EGGNOG_MAPPER.out.versions)
    }

    //
    // MODULE: Collect all software versions
    // =======

    ch_version_yaml = Channel.empty()

    CUSTOM_DUMPSOFTWAREVERSIONS(
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
    ch_version_yaml = CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect()

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowGenomeannotator.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowGenomeannotator.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_version_yaml)
    ch_multiqc_files = ch_multiqc_files.mix(ch_busco_qc.collect().ifEmpty([]))

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config.collect().ifEmpty([]),
        ch_multiqc_custom_config.collect().ifEmpty([]),
        ch_multiqc_logo.collect().ifEmpty([])
    )

    multiqc_report = MULTIQC.out.report.toList()

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
