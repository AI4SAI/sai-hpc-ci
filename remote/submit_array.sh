#!/usr/bin/env bash
set -euo pipefail
: "${PLAN_FILE:?validated plan required}"
: "${PROFILE_FILE:?trusted profile required}"
: "${REMOTE_ROOT:?task root required}"
: "${CONTROLLER_ROOT:?trusted controller root required}"
source "${PROFILE_FILE}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
export LD_PRELOAD="${LD_PRELOAD:-}"
export CPATH="${CPATH:-}"
export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-}"
source "${MODULE_INIT}"
module purge
for module_name in ${MODULES}; do module load "${module_name}"; done
python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); [print(i,t["nodes"],t["gpus_per_node"],t["ranks_per_node"],t["timeout_minutes"]) for i,t in enumerate(p["tests"]) ]' "${PLAN_FILE}" | while read -r index nodes gpus ranks timeout; do
  sbatch --parsable --array="${index}" --nodes="${nodes}" --ntasks="$((nodes * ranks))" --gpus="$((nodes * gpus))" --ntasks-per-node="${ranks}" --time="${timeout}" --partition="${PARTITION}" --qos="${QOS}" --export=ALL,PLAN_FILE,PROFILE_FILE,REMOTE_ROOT,CONTROLLER_ROOT "${SLURM_SCRIPT:?trusted sbatch script required}"
done
