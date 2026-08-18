#!/usr/bin/env bash
#SBATCH --ntasks=1
set -euo pipefail
exec python3 "${CONTROLLER_ROOT}/remote/run_array_task.py"
