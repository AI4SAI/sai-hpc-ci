#!/usr/bin/env bash
set -euo pipefail
for job in "$@"; do
  while squeue -h -j "$job" | grep -q .; do sleep 15; done
  state=$(sacct -X -n -o State -j "$job" | head -n 1 | tr -d ' ')
  case "$state" in COMPLETED) ;; *) echo "job $job ended in $state" >&2; exit 1;; esac
done
