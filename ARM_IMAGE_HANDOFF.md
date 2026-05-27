# R2E-Gym ARM Image Handoff

This repo contains the ARM64 image build changes and helper scripts for R2E-Gym.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -U pip
python3 -m pip install -e .
```

## Build

```bash
export REGISTRY=registry.example.com/namespace/r2e-gym
export WORKERS=8

python3 src/r2egym/repo_analysis/build_arm64_dockers.py \
  --instance-file r2e_gym_instance_ids.m1.txt \
  --state-file build_push_state.m1.json \
  --max-workers "${WORKERS}" \
  --cleanup-local \
  --push \
  --retry-failed \
  --registry "${REGISTRY}"
```

For Slurm:

```bash
REGISTRY=registry.example.com/namespace/r2e-gym sbatch sbatch_build_push.sh 1
```

## Verification Before Push

This R2E-Gym build wrapper does not currently have an integrated gold-patch verification gate before `--push`. The command above builds and pushes successfully built images; use the failed-instance lists below to filter known failures or add a separate validation pass before publishing a final registry.

Failed-instance lists are under `handoff/failed_instances/`.
