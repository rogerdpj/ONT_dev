FROM mambaorg/micromamba:1.5.7
LABEL authors="ROGER DE PEDRO JOVE" \
      description="Docker image containing the environment with all the tools for trimming ONT reads"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Create environment
RUN micromamba create -n trimming_env -y \
    -c bioconda -c conda-forge \
    filtlong=0.3.1 \
    porechop=0.2.4 \
    nanostat=1.6.0 \
    nanocomp=1.25.6 \
    && micromamba clean --all --yes

# Activate environment
ENV PATH=/opt/conda/envs/trimming_env/bin:$PATH

# Default shell
SHELL ["/bin/bash", "-c"]
