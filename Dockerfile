FROM ubuntu:22.04

ARG NEXTFLOW_VERSION=25.04.6
ARG VG_VERSION=1.69.0
ARG KMC_VERSION=3.2.4
ARG BCFTOOLS_VERSION=1.22
ARG SAMTOOLS_VERSION=1.22.1
ARG HTSLIB_VERSION=1.22.1
ARG GATK_URL=https://ndownloader.figshare.com/files/64029175
ARG PICARD_URL=https://ndownloader.figshare.com/files/64029172
ARG BEAGLE_URL=https://ndownloader.figshare.com/files/64029178

LABEL org.opencontainers.image.title="VarsGT" \
      org.opencontainers.image.description="Reproducible runtime for the VarsGT Nextflow workflow" \
      org.opencontainers.image.source="https://github.com/GooLey1025/VarsGT"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NXF_HOME=/opt/nextflow \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    JAVA8_HOME=/opt/java8 \
    MAMBA_ROOT_PREFIX=/opt/micromamba \
    PATH=/opt/micromamba/envs/varsgt/bin:/usr/lib/jvm/java-17-openjdk-amd64/bin:/opt/java8/bin:/usr/local/bin:$PATH

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        bash \
        bzip2 \
        ca-certificates \
        curl \
        gzip \
        openjdk-17-jre-headless \
        procps \
        tar \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Keep Java 17 as the default for Nextflow, Picard, and Beagle. GATK 3.7
# explicitly uses /opt/java8/bin/java through the VarsGT parameter file.
RUN mkdir -p /opt/java8 /opt/nextflow \
    && curl -fsSL \
        "https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jdk/hotspot/normal/eclipse" \
        -o /tmp/java8.tar.gz \
    && tar -xzf /tmp/java8.tar.gz -C /opt/java8 --strip-components=1 \
    && rm /tmp/java8.tar.gz \
    && ln -s /usr/lib/jvm/java-17-openjdk-amd64/bin/java /usr/local/bin/java17 \
    && ln -s /opt/java8/bin/java /usr/local/bin/java8

RUN curl -fsSL "https://micro.mamba.pm/api/micromamba/linux-64/latest" \
        | tar -xj -C /usr/local/bin --strip-components=1 bin/micromamba \
    && micromamba create -y -n varsgt \
        -c conda-forge \
        -c bioconda \
        "pangenie" \
        "bcftools=${BCFTOOLS_VERSION}" \
        "samtools=${SAMTOOLS_VERSION}" \
        "htslib=${HTSLIB_VERSION}" \
    && micromamba clean --all --yes

RUN curl -fL \
        "https://github.com/vgteam/vg/releases/download/v${VG_VERSION}/vg" \
        -o /usr/local/bin/vg \
    && chmod 0755 /usr/local/bin/vg \
    && vg version

RUN curl -fL \
        "https://github.com/refresh-bio/KMC/releases/download/v${KMC_VERSION}/KMC${KMC_VERSION}.linux.x64.tar.gz" \
        -o /tmp/kmc.tar.gz \
    && tar -xzf /tmp/kmc.tar.gz -C /opt \
    && install -m 0755 /opt/bin/kmc /usr/local/bin/kmc \
    && install -m 0755 /opt/bin/kmc_dump /usr/local/bin/kmc_dump \
    && install -m 0755 /opt/bin/kmc_tools /usr/local/bin/kmc_tools \
    && rm -rf /opt/bin /tmp/kmc.tar.gz \
    && kmc 2>&1 | awk 'NR <= 2 { print }'

RUN curl -fL \
        "https://github.com/nextflow-io/nextflow/releases/download/v${NEXTFLOW_VERSION}/nextflow" \
        -o /usr/local/bin/nextflow \
    && chmod 0755 /usr/local/bin/nextflow

WORKDIR /opt/varsgt

RUN mkdir -p softwares \
    && curl -fL "${GATK_URL}" -o softwares/GenomeAnalysisTK3.7.jar \
    && curl -fL "${PICARD_URL}" -o softwares/picard.jar \
    && curl -fL "${BEAGLE_URL}" -o softwares/beagle.27Feb25.75f.jar

COPY main.nf vcf_filter_impute.nf README.md varsgt ./
COPY modules ./modules
COPY scripts ./scripts
COPY docs ./docs
COPY 705rice.template.params.yaml 1171rice.template.params.yaml test.params.yaml ./

RUN chmod 0755 scripts/*.sh varsgt \
    && java17 -version \
    && java8 -version \
    && nextflow -version \
    && vg version \
    && PanGenie --help >/dev/null \
    && kmc 2>&1 | awk 'NR <= 2 { print }' \
    && bcftools --version \
    && samtools --version \
    && bgzip --version \
    && tabix --version

VOLUME ["/data", "/results", "/work", "/config"]

ENTRYPOINT ["nextflow"]
CMD ["-version"]
