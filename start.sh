#!/bin/bash

export ISSM_DIR=/opt/issm
export PETSC_DIR=/opt/petsc

source /opt/conda/etc/profile.d/conda.sh
conda activate base

source ${ISSM_DIR}/etc/environment.sh

export LD_LIBRARY_PATH="/opt/conda/lib:/opt/issm/lib:/opt/petsc/lib:/opt/issm/externalpackages/triangle/install/lib:${LD_LIBRARY_PATH}"

if [ $# -eq 0 ]; then
    /bin/bash
else
    exec "$@"
fi
