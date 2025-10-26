# Use micromamba base image
FROM ghcr.io/mamba-org/micromamba:1.5.1

# Set root as default user (micromamba image uses root by default, but explicit is better)
USER root

# Install required packages
RUN micromamba install -y -n base -c conda-forge -c bioconda \
        manta \
        samtools \
        python \
        awscli && \
    micromamba clean -a -y

# Ensure micromamba binaries are in PATH
ENV PATH="/opt/conda/bin:${PATH}"

# Set working directory
WORKDIR /data

# Default command
CMD ["bash"]