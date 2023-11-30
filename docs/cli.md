# Genomeannotator command line options

## input_output_options Input/output options

### --assembly [ string ]
Path to the genome assembly.

### --outdir [ string ]
The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure.

### --email [ string ]
Email address for completion summary.

### --multiqc_title [ string ]
MultiQC report title. Printed as page header, used for filename if not otherwise specified.

### --rnaseq_samples [ string ]
Path to samplesheet for RNAseq data.

### --proteins [ string ]
Path to a fasta file with proteins

### --proteins_targeted [ string ]
Path to a fasta file with proteins

### --transcripts [ string ]
Path to a fasta file with transcripts/ESTs

### --rm_lib [ string ]
Path to a fasta file with known repeat sequences for this organism

### --references [ string ]
Path to samplesheet for Reference genomes and annotations.

## annotation_module_options Options for pipeline behavior

### --npart_size [ integer ]
Chunk size for splitting the assembly.

### --max_intron_size [ integer ]
Maximum length of expected introns in bp.

### --min_contig_size [ integer ]
Minimum size of contig to consider

### --rm_species [ string ]
Taxonomic group to guide repeat masking.

### --rm_db [ string ]
A database of curated repeats in EMBL format.

### --busco_lineage [ string ]
Name of a BUSCO taxonomic group to evaluate the completeness of annotated gene set(s).

### --busco_db_path [ string ]
Path to the local BUSCO data.

### --eggnog_mapper_db [ string ]
Path to a pre-installed EggnogMapper database.

### --eggnog_taxonomy [ integer ]
Taxonomy ID for EggnogMapper

### --dummy_gff [ string ]
A placeholder gff file to help trigger certain processes.

## augustus_options Options for ab-initio gene finding

### --aug_species [ string ]
AUGUSTUS species model to use.

### --aug_options [ string ]
Options to pass to AUGUSTUS.

### --aug_config_dir [ string ]
A config directory for AUGUSTUS

### --aug_extrinsic_cfg [ string ]
Custom AUGUSTUS extrinsic config file path

### --aug_chunk_length [ integer ]
Length of annotation chunks in AUGUSTUS

### --aug_training [ boolean ]
Enable training of a new AUGUSTUS profile.

### --pri_prot [ integer ]
Priority for protein-derived hints for gene building.

### --pri_prot_target [ integer ]
Priority for targeted protein evidences

### --pri_est [ integer ]
Priority for transcript evidences

### --pri_rnaseq [ integer ]
Priority for RNAseq splice junction evidences

### --pri_wiggle [ integer ]
Priority for RNAseq exon coverage evidences

### --pri_trans [ integer ]
Priority for trans-mapped gene model evidences

### --t_est [ string ]
Evidence label for transcriptome data

### --t_prot [ string ]
Evidence label for protein data

### --t_rnaseq [ string ]
Evidence label for RNAseq data

## protein_tool_options Options for protein data processing

### --spaln_taxon [ string ]
Taxon model to use for SPALN protein alignments.

### --spaln_options [ string ]
SPALN custom options.

### --spaln_protein_id [ integer ]
SPALN id threshold for aligning.

### --min_prot_length [ integer ]
Minimum size of a protein sequence to be included.

### --nproteins [ integer ]
Numbe of proteins per alignment job.

### --spaln_q [ integer ]
Q value for the SPALN alignment algorithm.

### --spaln_protein_id_targeted [ integer ]
ID threshold for targeted protein alignments.

## pasa_options Options for PASA behavior

### --pasa_nmodels [ integer ]
Number of PASA models to select for AUGUSTUS training.

### --pasa_config_file [ string ]
Built-in config file for PASA.

### --pasa_aligner [ string ]
Aligners to use in PASA pipeline.

## evm_options Options for EvidenceModeler behavior

### --evm_weights [ string ]
Weights file for EVM.

### --nevm [ integer ]
Number of EVM jobs per chunk.

### --evm_segment_size [ integer ]
The segment size to use in EVM in bp.

### --evm_overlap_size [ integer ]
The overlap size to use in EVM in bp.

## annotation_tool_options Options for tool behavior

### --trinity [ boolean ]
Activate the trinity assembly sub-pipeline

### --pasa [ boolean ]
Activate the PASA sub-pipeline

### --evm [ boolean ]
Activate the EvidenceModeler sub-pipeline

### --ncrna [ boolean ]
Activate search for ncRNAs with RFam/infernal

## institutional_config_options Institutional config options

### --custom_config_version [ string ]
Git commit id for Institutional configs.

### --custom_config_base [ string ]
Base directory for Institutional configs.

### --config_profile_name [ string ]
Institutional config name.

### --config_profile_description [ string ]
Institutional config description.

### --config_profile_contact [ string ]
Institutional config contact information.

### --config_profile_url [ string ]
Institutional config URL link.

## max_job_request_options Max job request options

### --max_cpus [ integer ]
Maximum number of CPUs that can be requested for any single job.

### --max_memory [ string ]
Maximum amount of memory that can be requested for any single job.

### --max_time [ string ]
Maximum amount of time that can be requested for any single job.

## generic_options Generic options

### --help [ boolean ]
Display help text.

### --version [ boolean ]
Display version and exit.

### --publish_dir_mode [ string ]
Method used to save pipeline results to output directory.

### --email_on_fail [ string ]
Email address for completion summary, only when pipeline fails.

### --plaintext_email [ boolean ]
Send plain-text email instead of HTML.

### --max_multiqc_email_size [ string ]
File size limit when attaching MultiQC reports to summary emails.

### --monochrome_logs [ boolean ]
Do not use coloured log outputs.

### --hook_url [ string ]
Incoming hook URL for messaging service

### --multiqc_config [ string ]
Custom config file to supply to MultiQC.

### --multiqc_logo [ string ]
Custom logo file to supply to MultiQC. File name must also be set in the MultiQC config file

### --multiqc_methods_description [ string ]
Custom MultiQC yaml file containing HTML including a methods description.

### --tracedir [ string ]
Directory to keep pipeline Nextflow logs and reports.

### --validate_params [ boolean ]
Boolean whether to validate parameters against the schema at runtime

### --show_hidden_params [ boolean ]
Show all params when using `--help`

