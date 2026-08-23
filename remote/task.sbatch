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
DIAGNOSTIC_DIR="$REMOTE_ROOT/diagnostics/${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID:-0}"
mkdir -p "$DIAGNOSTIC_DIR"
exec > >(tee -a "$DIAGNOSTIC_DIR/batch.log") 2>&1
diag() { "$@" >> "$DIAGNOSTIC_DIR/commands.log" 2>&1 || true; }
export HOME=$(getent passwd "$SLURM_JOB_USER" | cut -d: -f6)
export USER=$SLURM_JOB_USER LOGNAME=$SLURM_JOB_USER
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

source "$PROFILE_FILE"
export ROOTFS="$REMOTE_ROOT/rootfs"
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}
export LD_PRELOAD=${LD_PRELOAD:-}
export CPATH=${CPATH:-}
export CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH:-}
source "$MODULE_INIT"
module purge
for module_name in $MODULES; do module load "$module_name"; done
diag id
diag env
diag bash -c 'printf "partition=%s qos=%s account=%s tres=%s gres=%s\\n" "$SLURM_JOB_PARTITION" "$SLURM_JOB_QOS" "$SLURM_JOB_ACCOUNT" "$SLURM_JOB_TRES_PER_NODE" "$SLURM_JOB_GRES"'
diag bash -c 'command -v sbatch srun python3 apptainer module'
diag bash -c 'module --version'
diag bash -c 'module -t list'
diag apptainer --version
diag nvidia-smi -L
diag srun --version
MPS_MAPPING_FILE="$MPS_MAPPING_ROOT/${SLURM_JOB_PARTITION}.bash"
test -r "$MPS_MAPPING_FILE"
source "$MPS_MAPPING_FILE"
diag bash -c 'printf "MAP_OPT=%s GPUS_PER_SOCKET=%s CORES_PER_SOCKET=%s CORES_PER_GPU=%s RANKS_PER_GPU=%s\\n" "$MAP_OPT" "$GPUS_PER_SOCKET" "$CORES_PER_SOCKET" "$CORES_PER_GPU" "$RANKS_PER_GPU"'
export SLURM_EXPORT_ENV=ALL
export OMPI_MCA_plm_slurm_args=--external-launcher
export PRTE_MCA_plm_slurm_args=--external-launcher
exec python3 "${CONTROLLER_ROOT}/run_array_task.py"
