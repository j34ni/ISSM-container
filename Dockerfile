FROM ubuntu:22.04

ENV TZ="Europe/Oslo"
ENV PATH="/opt/conda/bin:$PATH"
SHELL ["/bin/bash", "-c"]

RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential ca-certificates tzdata wget unzip && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q -nc --no-check-certificate -P /var/tmp https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh && \
    bash /var/tmp/Miniforge3-Linux-x86_64.sh -b -p /opt/conda && \
    rm /var/tmp/Miniforge3-Linux-x86_64.sh

RUN source /opt/conda/etc/profile.d/conda.sh && \
    mamba install -y -c j34ni -c conda-forge \
        autoconf automake "cmake=3.27.*" \
        gcc_linux-64=13 gxx_linux-64=13 gfortran_linux-64=13 \
        libtool m4 make matplotlib metis mvapich=4.1 netcdf4 \
        numpy "openblas>=0.3.23" pkg-config python=3.11 scipy zlib \
        "j34ni::esme_hdf5_mvapich_4_1" \
        "j34ni::mumps-mpi" \
        "j34ni::mumps-include" \
        "j34ni::parmetis" \
        "j34ni::scalapack" && \
    conda clean -afy

ENV PETSC_VERSION=3.22.2
ENV PETSC_DIR=/opt/petsc
ENV PETSC_ARCH=arch-linux-opt

RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    export LD_LIBRARY_PATH="/opt/conda/lib:${LD_LIBRARY_PATH}" && \
    export FI_PROVIDER=tcp && \
    wget -q -nc --no-check-certificate -P /var/tmp https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-${PETSC_VERSION}.tar.gz && \
    tar -xf /var/tmp/petsc-${PETSC_VERSION}.tar.gz -C /var/tmp && \
    cd /var/tmp/petsc-${PETSC_VERSION} && \
    export PETSC_DIR=/var/tmp/petsc-${PETSC_VERSION} && \
    python3 ./configure \
        --prefix=/opt/petsc \
        PETSC_ARCH=${PETSC_ARCH} \
        --with-cc=mpicc \
        --with-cxx=mpicxx \
        --with-fc=mpifort \
        FFLAGS="-fallow-argument-mismatch" \
        LDFLAGS="-L/opt/conda/lib -Wl,-rpath,/opt/conda/lib" \
        --with-debugging=0 \
        --with-shared-libraries=1 \
        --COPTFLAGS="-O3" \
        --CXXOPTFLAGS="-O3" \
        --FOPTFLAGS="-O3" \
        --download-fblaslapack \
        --with-metis-dir=/opt/conda \
        --with-parmetis-dir=/opt/conda \
        --with-scalapack-dir=/opt/conda \
        --with-mumps-dir=/opt/conda \
        --with-hdf5-dir=/opt/conda \
        --with-ssl=0 --with-x=0 --with-openmp=1 && \
    make PETSC_DIR=/var/tmp/petsc-${PETSC_VERSION} PETSC_ARCH=${PETSC_ARCH} MAKE_NP=$(nproc) all && \
    make PETSC_DIR=/var/tmp/petsc-${PETSC_VERSION} PETSC_ARCH=${PETSC_ARCH} install && \
    rm -rf /var/tmp/petsc-${PETSC_VERSION}*

ENV ISSM_VERSION=2026.2
ENV ISSM_DIR=/opt/issm

RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    wget -q -nc --no-check-certificate -P /var/tmp https://github.com/ISSMteam/ISSM/archive/refs/tags/${ISSM_VERSION}.tar.gz && \
    tar -xf /var/tmp/${ISSM_VERSION}.tar.gz -C /var/tmp && \
    mv /var/tmp/ISSM-${ISSM_VERSION} ${ISSM_DIR} && \
    rm /var/tmp/${ISSM_VERSION}.tar.gz

RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    cd ${ISSM_DIR}/externalpackages/triangle && ./install-linux.sh

RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    export LD_LIBRARY_PATH="/opt/conda/lib:${LD_LIBRARY_PATH}" && \
    export FI_PROVIDER=tcp && \
    export NUMPY_INC=$(python3 -c "import numpy; print(numpy.get_include())") && \
    export C_INCLUDE_PATH="${NUMPY_INC}:${NUMPY_INC}/numpy:${C_INCLUDE_PATH}" && \
    export C_INCLUDE_PATH="/opt/conda/include:${C_INCLUDE_PATH}" && \
    export CPLUS_INCLUDE_PATH="${NUMPY_INC}:${NUMPY_INC}/numpy:${CPLUS_INCLUDE_PATH}" && \
    export CPLUS_INCLUDE_PATH="/opt/conda/include:${CPLUS_INCLUDE_PATH}" && \
    cd ${ISSM_DIR} && \
    autoreconf -ivf && \
    ./configure \
        --prefix=${ISSM_DIR} \
        --with-numthreads=$(nproc) \
        --with-python-dir=/opt/conda \
        --with-python-version=3.11 \
        --with-python-numpy-dir=${NUMPY_INC} \
        --with-fortran-lib="-L/opt/conda/lib -lgfortran" \
        --with-mpi-include=/opt/conda/include \
        --with-mpi-libflags="-L/opt/conda/lib -lmpi -lmpicxx -lmpifort" \
        --with-petsc-dir=/opt/petsc \
        --with-blas-lapack-dir=/opt/petsc \
        --with-metis-dir=/opt/conda \
        --with-parmetis-dir=/opt/conda \
        --with-mumps-dir=/opt/conda \
        --with-hdf5-dir=/opt/conda \
        --with-triangle-dir=${ISSM_DIR}/externalpackages/triangle/install && \
    make -j$(nproc) && \
    make install

ENV ISSM_DIR=${ISSM_DIR}
ENV PETSC_DIR=${PETSC_DIR}
ENV PYTHONPATH="${ISSM_DIR}/bin:${ISSM_DIR}/lib"

COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh
CMD ["/opt/start.sh"]
