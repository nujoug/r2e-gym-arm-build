"""Extract test_file_codes / test_file_names from the HuggingFace R2E-Gym dataset
and write them to test_data/<repo_key>/<commit_hash>.json so that
build_arm64_dockers.py can embed real tests into Docker images.

Usage:
    pip install datasets
    python extract_test_data.py [--dataset R2E-Gym/R2E-Gym-Full] [--instance-file r2e_gym_instance_ids.txt]
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from datasets import load_dataset


REPO_ALIASES = {
    "pandas": "pandas",
    "numpy": "numpy",
    "datalad": "datalad",
    "scrapy": "scrapy",
    "aiohttp": "aiohttp",
    "tornado": "tornado",
    "pillow": "pillow",
    "Pillow": "pillow",
    "orange3": "orange3",
    "sympy": "sympy",
    "pyramid": "pyramid",
    "coveragepy": "coveragepy",
    "bokeh": "bokeh",
}


def parse_instance_id(instance_id: str) -> tuple[str, str]:
    """Return (repo_key, commit_hash) from an instance id string."""
    cleaned = instance_id.strip()
    owner_repo, commit_hash = cleaned.rsplit("-", 1)
    _owner, repo_raw = owner_repo.split("__", 1)
    repo_key = REPO_ALIASES.get(repo_raw.lower(), repo_raw.lower())
    return repo_key, commit_hash


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dataset",
        type=str,
        default="R2E-Gym/R2E-Gym-Full",
        help="HuggingFace dataset name",
    )
    parser.add_argument(
        "--split",
        type=str,
        default="train",
    )
    parser.add_argument(
        "--instance-file",
        type=Path,
        default=None,
        help="Only extract for instance IDs listed in this file (optional, extracts all if omitted)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("test_data"),
    )
    args = parser.parse_args()

    wanted_commits: set[tuple[str, str]] | None = None
    if args.instance_file is not None:
        wanted_commits = set()
        with open(args.instance_file) as f:
            for line in f:
                line = line.strip()
                if line:
                    wanted_commits.add(parse_instance_id(line))
        print(f"Filtering to {len(wanted_commits)} instances from {args.instance_file}")

    print(f"Loading dataset {args.dataset} ...")
    ds = load_dataset(args.dataset, split=args.split)
    print(f"Loaded {len(ds)} rows")

    stats: Counter[str] = Counter()
    written = 0
    skipped_no_tests = 0
    skipped_not_wanted = 0

    for row in ds:
        repo_name = row.get("repo_name", "")
        commit_hash = row.get("commit_hash", "")
        repo_key = REPO_ALIASES.get(repo_name, repo_name.lower())

        if wanted_commits is not None and (repo_key, commit_hash) not in wanted_commits:
            skipped_not_wanted += 1
            continue

        exec_result_str = row.get("execution_result_content", "")
        if not exec_result_str:
            skipped_no_tests += 1
            continue

        try:
            exec_result = json.loads(exec_result_str)
        except json.JSONDecodeError:
            skipped_no_tests += 1
            continue

        test_file_codes = exec_result.get("test_file_codes", []) or []
        test_file_names = exec_result.get("test_file_names", []) or []

        if not test_file_codes:
            skipped_no_tests += 1
            continue

        out_dir = args.output_dir / repo_key
        out_dir.mkdir(parents=True, exist_ok=True)
        out_file = out_dir / f"{commit_hash}.json"
        out_file.write_text(
            json.dumps(
                {"test_file_codes": test_file_codes, "test_file_names": test_file_names},
                indent=2,
            ),
            encoding="utf-8",
        )
        written += 1
        stats[repo_key] += 1

    print(f"\nDone. Written: {written}, skipped (no tests): {skipped_no_tests}, skipped (not wanted): {skipped_not_wanted}")
    print("Per repo:")
    for repo, count in sorted(stats.items()):
        print(f"  {repo}: {count}")


if __name__ == "__main__":
    main()
