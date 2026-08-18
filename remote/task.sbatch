#!/usr/bin/env bash
#SBATCH --ntasks=1
set -euo pipefail
exec python3 "${CONTROLLER_ROOT}/run_array_task.py"
