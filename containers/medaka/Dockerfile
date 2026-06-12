FROM mambaorg/micromamba:1.5.7
LABEL authors="ROGER DE PEDRO JOVE" \
      description="Docker image containing the environment with medaka"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Create environment
RUN micromamba create -n medaka_env -y \
    -c conda-forge -c nanoporetech -c bioconda \
    medaka=2.2.2 \
    && micromamba clean --all --yes

# Activate environment
ENV PATH=/opt/conda/envs/medaka_env/bin:$PATH

# Default shell
SHELL ["/bin/bash", "-c"]