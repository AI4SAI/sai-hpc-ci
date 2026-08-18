# sai-hpc-ci

Reusable, declarative remote GPU/HPC CI for multi-node Slurm clusters.

The controller owns the host-side execution boundary: modules, Slurm, Apptainer, MPI launch, bind mounts, cleanup, and result collection. A caller supplies a repository SHA and a validated list of container-internal commands. Project SSH credentials are supplied by the caller at workflow runtime; this repository does not store project keys.

Pin the reusable workflow to a reviewed commit (current controller release: `79919193a8722d4a42c2cd6a905a884afb6a0bc7`):

```yaml
jobs:
  gpu:
    uses: AI4SAI/sai-hpc-ci/.github/workflows/hpc-test.yml@79919193a8722d4a42c2cd6a905a884afb6a0bc7
    with:
      source_repository: ${{ github.repository }}
      source_sha: ${{ github.sha }}
      cluster_profile: sai-cuda12-openmpi5
      remote_root: ~/sai-hpc-ci
      tests_json: ${{ vars.GPU_TEST_PLAN }}
    secrets:
      REMOTE_USER: ${{ secrets.REMOTE_USER }}
      REMOTE_SSH_PRIVATE_KEY: ${{ secrets.REMOTE_SSH_PRIVATE_KEY }}
```

The caller owns `REMOTE_USER`, `REMOTE_SSH_PRIVATE_KEY`, and the `SAI_SSH_KNOWN_HOSTS` repository variable. The controller never executes caller-provided shell code on the host. Commands run inside Apptainer with source/software binds read-only and only per-task build/results/tmp directories writable. The sample profile is a site-specific template and must be reviewed before deployment. When publishing a new controller release, update the pinned caller ref and the workflow's internal controller checkout ref together.
