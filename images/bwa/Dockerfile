FROM ubuntu:20.04
#Prevents installation processes from asking interactive questions. like yes or no etc
ENV DEBIAN_FRONTEND=noninteractive

# Install all tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    samtools \
    bwa \
    && rm -rf /var/lib/apt/lists/*
#rm -rf /var/lib/apt/lists/*	Removes package indexes(metadata) to reduce image size

# Install awscli
RUN pip3 install awscli

# Debug: Check if each tool is installed and working
RUN which bwa  || echo "bwa failed"
RUN which samtools && samtools --version || echo "samtools failed" 
RUN which aws && aws --version || echo "aws failed"

WORKDIR /workspace

#"CMD specifies the default command to execute when a Docker container starts. 
#In this example, /bin/bash opens an interactive Bash shell inside the container when run with an interactive terminal."
CMD ["/bin/bash"]
