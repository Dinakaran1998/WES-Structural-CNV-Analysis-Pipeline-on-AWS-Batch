#!/usr/bin/env nextflow

/*
 * Whole Exome Structural and CNV Analysis Pipeline
 * using BWA, GATK, and Manta on AWS Batch
 */

params.reads     = "s3://aws-batch-input-bioinformatics/wes_data/*_{1,2}.fastq.gz"
params.genome    = "s3://aws-batch-input-bioinformatics/genomics_ref_data/hg38.fa"
params.outdir    = "s3://aws-batch-input-bioinformatics/wes_structural/results"
params.intervals = "s3://aws-batch-input-bioinformatics/bed/Illumina_Exome_Target_gene_annotated_v1.2.hg38.bed"


/*
 * STEP 1: Alignment with BWA
 */
process ALIGN_BWA {
    container '<aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/bwa:latest'
    tag "${sample_id}"
    publishDir "${params.outdir}/align", mode: 'copy'
    #The output is stored in both locations:
    #1. AWS Batch EC2 local storage: The original output remains in the Nextflow work/ directory.
    #2. Amazon S3: Nextflow copies the declared output files to your publishDir S3 destination.

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam")

    script:
    """
    # Download genome reference and index files
    aws s3 cp ${params.genome} .
    aws s3 cp ${params.genome}.fai .
    aws s3 cp ${params.genome}.amb .
    aws s3 cp ${params.genome}.ann .
    aws s3 cp ${params.genome}.bwt .
    aws s3 cp ${params.genome}.pac .
    aws s3 cp ${params.genome}.sa .

    # Align and sort
    bwa mem -t ${task.cpus} -R "@RG\\tID:${sample_id}\\tSM:${sample_id}\\tPL:ILLUMINA" \
        hg38.fa ${reads[0]} ${reads[1]} | \
        samtools sort -o ${sample_id}.sorted.bam

    samtools index ${sample_id}.sorted.bam
    """
}


/*
 * STEP 2: Mark Duplicates with GATK
 */
process MARK_DUP {
    container '<aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/gatk:latest'
    tag "${sample_id}"
    publishDir "${params.outdir}/bam", mode: 'copy'

    input:
    tuple val(sample_id), path(bam)

    output:
    tuple val(sample_id), path("${sample_id}.sorted.markdup.bam"), path("${sample_id}.sorted.markdup.bam.bai")

    script:
    """
    gatk MarkDuplicates \
        -I ${bam} \
        -O ${sample_id}.sorted.markdup.bam \
        -M ${sample_id}.markdup.metrics.txt

    samtools index ${sample_id}.sorted.markdup.bam
    """
}


/*
 * STEP 3: CNV Calling using GATK CNV tools
 */
process CNV_CALLING {
    container '<aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/gatk:latest'
    tag "${sample_id}"
    publishDir "${params.outdir}/cnv", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    path("${sample_id}.sorted.markdup.cnv.vcf")

    script:
    """
    aws s3 cp ${params.intervals} target_intervals.bed

    gatk CollectReadCounts \
        -I ${bam} \
        -L target_intervals.bed \
        --interval-merging-rule OVERLAPPING_ONLY \
        -O ${sample_id}.sorted.markdup.counts.hdf5

    gatk CreateReadCountPanelOfNormals \
        -I ${sample_id}.sorted.markdup.counts.hdf5 \
        -O pon.hdf5

    gatk DenoiseReadCounts \
        -I ${sample_id}.sorted.markdup.counts.hdf5 \
        --count-panel-of-normals pon.hdf5 \
        --standardized-copy-ratios ${sample_id}.standardizedCR.tsv \
        --denoised-copy-ratios ${sample_id}.denoisedCR.tsv

    gatk ModelSegments \
        --denoised-copy-ratios ${sample_id}.denoisedCR.tsv \
        --output . \
        --output-prefix ${sample_id}

    gatk CallCopyRatioSegments \
        -I ${sample_id}.cr.seg \
        -O ${sample_id}.sorted.markdup.cnv.vcf
    """
}


/*
 * STEP 4: Structural Variant Calling using Manta
 */
/*
 * STEP 4: Structural Variant Calling using Manta
 */
process SV_CALLING {
    container '<aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/manta:latest'
    tag "${sample_id}"
    publishDir "${params.outdir}/sv", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    path("${sample_id}.sv.vcf.gz")           // Main structural variants
    path("${sample_id}.candidateSV.vcf.gz")  // Candidate variants
    path("${sample_id}.smallIndels.vcf.gz")  // Small indels

    script:
    """
    # Copy reference genome
    aws s3 cp ${params.genome} .
    aws s3 cp ${params.genome}.fai .

    # Run Manta
    configManta.py --bam ${bam} --referenceFasta hg38.fa --runDir manta_${sample_id}
    manta_${sample_id}/runWorkflow.py -m local -j ${task.cpus}

    # Copy all main VCF outputs
    cp manta_${sample_id}/results/variants/diploidSV.vcf.gz ${sample_id}.sv.vcf.gz
    cp manta_${sample_id}/results/variants/candidateSV.vcf.gz ${sample_id}.candidateSV.vcf.gz
    cp manta_${sample_id}/results/variants/candidateSmallIndels.vcf.gz ${sample_id}.smallIndels.vcf.gz

    echo "All output files created:"
    ls -lh *.vcf.gz
    """
}

/*
 * WORKFLOW DEFINITION
 */
workflow {
    read_pairs_ch = Channel.fromFilePairs(params.reads)

    aligned_bam_ch = ALIGN_BWA(read_pairs_ch)
    marked_bam_ch  = MARK_DUP(aligned_bam_ch)

    CNV_CALLING(marked_bam_ch)
    SV_CALLING(marked_bam_ch)
}
