#!/bin/bash
#SBATCH --partition=YOUR_PARTITION
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --job-name=r2e-gym-build
#SBATCH --output=logs/sbatch_build_push_%j.log
#SBATCH --error=logs/sbatch_build_push_%j.log

set -euo pipefail

# Usage:
#   sbatch --partition=<your-partition> sbatch_build_push.sh <shard>
# where <shard> is one of: 1, 2, 3, 4
SHARD="${1:-}"
if [[ "$SHARD" != "1" && "$SHARD" != "2" && "$SHARD" != "3" && "$SHARD" != "4" ]]; then
    echo "Usage: sbatch [slurm options] $0 <shard>"
    echo "Example: sbatch --partition=my-partition $0 1"
    exit 1
fi

WORKDIR="${WORKDIR:-${SLURM_SUBMIT_DIR:-$PWD}}"
cd "${WORKDIR}"
mkdir -p logs

export HF_HOME="${HF_HOME:-${HOME}/.cache/huggingface}"
source .venv/bin/activate

WORKERS="${WORKERS:-8}"
INSTANCE_IDS_FILE="${INSTANCE_IDS_FILE:-r2e_gym_instance_ids.m${SHARD}.txt}"
STATE_FILE="${STATE_FILE:-build_push_state.m${SHARD}.json}"
REGISTRY="${REGISTRY:-registry.example.com/namespace/r2e-gym}"
PLATFORM="${PLATFORM:-linux/arm64}"

echo "=== Job started at $(date) ==="
echo "Node: $(hostname)"
echo "Architecture: $(uname -m)"
echo "Docker version: $(docker --version)"
echo "Shard: ${SHARD}"
echo "Partition: ${SLURM_JOB_PARTITION:-unknown}"
echo "Workers: ${WORKERS}"
echo "Instance file: ${INSTANCE_IDS_FILE}"
echo "State file: ${STATE_FILE}"
echo "Registry: ${REGISTRY}"
echo "Platform: ${PLATFORM}"
echo "==============================="

CMD=(
    python3 "src/r2egym/repo_analysis/build_arm64_dockers.py"
    --instance-file "${INSTANCE_IDS_FILE}"
    --state-file "${STATE_FILE}"
    --max-workers "${WORKERS}"
    --cleanup-local
    --push
    --retry-failed
    --registry "${REGISTRY}"
)

echo "Running: ${CMD[*]}"
"${CMD[@]}"

echo "=== Job finished at $(date) ==="
