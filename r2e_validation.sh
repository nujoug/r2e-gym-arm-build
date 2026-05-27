#!/bin/bash
#SBATCH --partition=YOUR_PARTITION
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --job-name=r2e-gym-validation
#SBATCH --output=logs/r2e_validation_%j.log
#SBATCH --error=logs/r2e_validation_%j.log

set -euo pipefail

WORKDIR="${WORKDIR:-${SLURM_SUBMIT_DIR:-$PWD}}"
cd "${WORKDIR}"
mkdir -p logs

export HF_HOME="${HF_HOME:-${HOME}/.cache/huggingface}"
source .venv/bin/activate

WORKERS="${WORKERS:-8}"
INSTANCE_IDS_FILE="${INSTANCE_IDS_FILE:-r2e_gym_instance_ids.validation.txt}"
STATE_FILE="${STATE_FILE:-build_push_state.validation.json}"
REGISTRY="${REGISTRY:-registry.example.com/namespace/r2e-gym}"

python3 src/r2egym/repo_analysis/build_arm64_dockers.py \
    --instance-file "${INSTANCE_IDS_FILE}" \
    --state-file "${STATE_FILE}" \
    --max-workers "${WORKERS}" \
    --cleanup-local \
    --push \
    --rebuild \
    --registry "${REGISTRY}"
