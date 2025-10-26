FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install all tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    samtools \
    bwa \
    && rm -rf /var/lib/apt/lists/*

# Install awscli
RUN pip3 install awscli

# Debug: Check if each tool is installed and working
RUN which bwa  || echo "bwa failed"
RUN which samtools && samtools --version || echo "samtools failed" 
RUN which aws && aws --version || echo "aws failed"

WORKDIR /workspace

CMD ["/bin/bash"]