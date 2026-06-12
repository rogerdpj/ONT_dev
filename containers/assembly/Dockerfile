FROM mambaorg/micromamba:1.5.7
LABEL authors="ROGER DE PEDRO JOVE" \
      description="Docker image containing the environment with all the tools for assembling ONT reads"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Create environment
RUN micromamba create -n assembly_env -y \
    -c bioconda -c conda-forge \
    flye=2.9.6 \
    nanostat=1.6.0 \
    gzip \
    coreutils \
    minimap2=2.31 \
    racon=1.5.0 \
    dnaapler=1.3.0 \
    && micromamba clean --all --yes

# Activate environment
ENV PATH=/opt/conda/envs/assembly_env/bin:$PATH

# Default shell
SHELL ["/bin/bash", "-c"]