#!/usr/bin/env bash
#SBATCH --ntasks=1
#SBATCH --output=task-%A_%a.out
set -euo pipefail
exec python3 "${CONTROLLER_ROOT}/run_array_task.py"
