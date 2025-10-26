FROM mambaorg/micromamba:1.4.0

# Run everything as root to avoid permission issues
USER root

WORKDIR /data

# Install GATK, samtools and AWS CLI in one go
RUN micromamba install -y -n base -c conda-forge -c bioconda \
    python=3.11 \
    gatk4=4.6.2 \
    samtools=1.22 \
    awscli \
    pandas \
    numpy && \
    micromamba clean --all --yes

# Set up environment
ENV PATH=/opt/conda/bin:$PATH

# Verify installations
RUN gatk --help && samtools --version && aws --version

# Default command
CMD ["bash"]