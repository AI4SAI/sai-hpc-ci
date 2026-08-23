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
python3 - "${PLAN_FILE}" <<'PY'
import json, os, subprocess, sys
plan = json.load(open(sys.argv[1], encoding="utf-8"))
for index, task in enumerate(plan["tests"]):
    command = ["sbatch", "--parsable", f"--array={index}", f"--nodes={task['nodes']}", f"--ntasks={task['nodes'] * task['ranks_per_node']}", f"--gpus-per-node={task['gpus_per_node']}", f"--ntasks-per-node={task['ranks_per_node']}", f"--time={task['timeout_minutes']}", f"--partition={task['partition']}", f"--qos={task['qos']}", "--export=NIL", os.environ["SLURM_SCRIPT"], os.path.abspath(os.environ["PLAN_FILE"]), os.path.abspath(os.environ["PROFILE_FILE"]), os.environ["REMOTE_ROOT"], os.environ["CONTROLLER_ROOT"], os.path.join(os.path.dirname(os.path.abspath(os.environ["PLAN_FILE"])), "source.tar.gz")]
    print(subprocess.check_output(command, text=True).strip())
PY
