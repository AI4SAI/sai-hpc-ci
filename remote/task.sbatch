#!/usr/bin/env bash
#SBATCH --ntasks=1
#SBATCH --output=task-%A_%a.out
set -euo pipefail
: "${SLURM_JOB_USER:?}"
: "${1:?plan path required}"
: "${2:?profile path required}"
: "${3:?remote root required}"
: "${4:?controller root required}"
: "${5:?source archive required}"
export PLAN_FILE=$1 PROFILE_FILE=$2 REMOTE_ROOT=$3 CONTROLLER_ROOT=$4 SOURCE_ARCHIVE=$5
export HOME=$(getent passwd "$SLURM_JOB_USER" | cut -d: -f6)
export USER=$SLURM_JOB_USER LOGNAME=$SLURM_JOB_USER
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

source "$PROFILE_FILE"
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}
export LD_PRELOAD=${LD_PRELOAD:-}
export CPATH=${CPATH:-}
export CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH:-}
source "$MODULE_INIT"
module purge
for module_name in $MODULES; do module load "$module_name"; done
MPS_MAPPING_FILE="$MPS_MAPPING_ROOT/${SLURM_JOB_PARTITION}.bash"
test -r "$MPS_MAPPING_FILE"
source "$MPS_MAPPING_FILE"
export SLURM_EXPORT_ENV=ALL
export OMPI_MCA_plm_slurm_args=--external-launcher
export PRTE_MCA_plm_slurm_args=--external-launcher
exec python3 "${CONTROLLER_ROOT}/run_array_task.py"
