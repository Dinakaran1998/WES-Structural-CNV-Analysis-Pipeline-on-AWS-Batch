

---

# WES Structural & CNV Analysis Pipeline on AWS Batch

## Project Overview

This project implements a **Whole Exome Sequencing (WES) pipeline** for **alignment, CNV, and structural variant (SV) calling**. The workflow is fully **AWS Batch-ready**, leveraging **Docker containers**, **S3 for storage**.
**Key features:**

* BWA alignment of paired-end FASTQ files
* MarkDuplicates with GATK
* CNV detection using GATK CNV tools
* Structural variant calling with Manta
* Cloud-native execution using Nextflow + AWS Batch
* Containerized workflows with all dependencies inside images

---

---

## Pipeline Overview

### Workflow Steps

1. **Alignment with BWA**

   * Input: Paired-end FASTQ
   * Output: Sorted BAM

2. **Mark Duplicates**

   * Tool: GATK MarkDuplicates
   * Output: BAM + BAM index

3. **CNV Calling**

   * Tool: GATK CNV
   * Input: BAM, target BED intervals
   * Output: CNV VCF

4. **Structural Variant Calling**

   * Tool: Manta
   * Output: SV VCF, candidate SVs, small indels

---

## Required Tools

| Tool     | Purpose                                |
| -------- | -------------------------------------- |
| BWA      | Alignment of FASTQ to reference genome |
| samtools | BAM file handling                      |
| GATK     | CNV calling and MarkDuplicates         |
| Manta    | Structural variant detection           |
| AWS CLI  | S3 staging and reference download      |
| Python   | Required by AWS CLI and GATK scripts   |

---

## Reference Files

* Genome FASTA: `hg38.fa`
* Index files: `.fai, .amb, .ann, .bwt, .pac, .sa`
* BED intervals: exome target regions

**Download example:**

```bash
aws s3 cp s3://aws-batch-input-bioinformatics/genomics_ref_data/hg38.fa .
aws s3 cp s3://aws-batch-input-bioinformatics/bed/Illumina_Exome_Target_gene_annotated_v1.2.hg38.bed .
```

---

---

## Docker Images

### BWA Container

```dockerfile
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y python3 python3-pip samtools bwa \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install awscli

WORKDIR /workspace
CMD ["/bin/bash"]
```

### GATK Container

```dockerfile
FROM mambaorg/micromamba:1.4.0
USER root
WORKDIR /data

RUN micromamba install -y -n base -c conda-forge -c bioconda \
    python=3.11 gatk4=4.6.2 samtools awscli pandas numpy \
    && micromamba clean --all --yes

ENV PATH=/opt/conda/bin:$PATH
CMD ["bash"]
```

### Manta Container

```dockerfile
FROM ghcr.io/mamba-org/micromamba:1.5.1
USER root
WORKDIR /data

RUN micromamba install -y -n base -c conda-forge -c bioconda \
    manta samtools python awscli \
    && micromamba clean -a -y

ENV PATH="/opt/conda/bin:${PATH}"
CMD ["bash"]
```

---

## Building & Pushing Docker Images

```bash
sudo docker build --no-cache -t bwa ./bwa
aws ecr create-repository --repository-name bwa --region us-east-1
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com
docker tag bwa:latest <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/bwa:latest
docker push <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/bwa:latest
```

Repeat for `gatk` and `manta`.

---

## Running the Pipeline

```bash
nextflow run main.nf -c nextflow.config -resume -profile awsbatch
```

---



---

## Troubleshooting

| Error                     | Cause                       | Fix                                                          |
| ------------------------- | --------------------------- | ------------------------------------------------------------ |
| `aws: command not found`  | Container missing AWS CLI   | Use multi-stage Docker image or micromamba to install awscli |
| `Job Pending`             | Nextflow `cpus` > EC2 vCPUs | Reduce `process.cpus` or increase instance type              |
| `No space left on device` | Instance storage full       | Use EFS or larger instance                                   |
| Can't stage files         | EFS not mounted             | Ensure launch template user-data script mounts EFS           |

---

## Key Learnings & Best Practices

1. **Container Isolation:** Ensure all dependencies (BWA, samtools, GATK, Manta, AWS CLI) are installed inside containers.
2. **CPU & Memory Management:** `process.cpus` ≤ EC2 vCPUs; over-requesting resources causes pending jobs.
3. **Multi-stage Docker Builds:** Keeps final images small while including essential tools.
4. **Reference Management:** Use EFS or S3 for large genome and interval files.
5. **AWS Batch Settings:** Use `stageInMode` and `stageOutMode` for reliable S3 file handling.

---
