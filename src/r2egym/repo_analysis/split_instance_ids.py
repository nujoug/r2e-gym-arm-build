import argparse
from collections import Counter
from pathlib import Path


DEFAULT_INPUT = Path("r2e_gym_instance_ids.txt")
DEFAULT_OUTPUT_PREFIX = "r2e_gym_instance_ids"

# Strict no-overlap-by-repo split selected previously.
STRICT_GROUPS = {
    "m1": {"pandas"},
    "m2": {"numpy", "tornado"},
    "m3": {"pillow", "scrapy", "pyramid"},
    "m4": {"orange3", "aiohttp", "datalad", "coveragepy"},
}

# Normalize repo owner/name variants to the keys used above.
REPO_ALIASES = {
    "pandas": "pandas",
    "numpy": "numpy",
    "pillow": "pillow",
    "orange3": "orange3",
    "aiohttp": "aiohttp",
    "tornado": "tornado",
    "scrapy": "scrapy",
    "pyramid": "pyramid",
    "datalad": "datalad",
    "coveragepy": "coveragepy",
}


def parse_repo_key(instance_id: str) -> str:
    owner_repo = instance_id.rsplit("-", 1)[0]
    _owner, repo_raw = owner_repo.split("__", 1)
    repo_key = repo_raw.lower()
    if repo_key not in REPO_ALIASES:
        raise ValueError(f"Unsupported repo in instance id: {instance_id}")
    return REPO_ALIASES[repo_key]


def main() -> None:
    parser = argparse.ArgumentParser(description="Split instance IDs into strict no-overlap repo groups.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Path to input instance-id file.")
    parser.add_argument(
        "--output-prefix",
        type=str,
        default=DEFAULT_OUTPUT_PREFIX,
        help="Prefix for output files, e.g. <prefix>.m1.txt",
    )
    args = parser.parse_args()

    lines = [x.strip() for x in args.input.read_text(encoding="utf-8").splitlines() if x.strip()]
    assignments: dict[str, list[str]] = {k: [] for k in STRICT_GROUPS}
    repo_counts_per_machine: dict[str, Counter] = {k: Counter() for k in STRICT_GROUPS}

    for line in lines:
        repo_key = parse_repo_key(line)
        target_machine = None
        for machine, repos in STRICT_GROUPS.items():
            if repo_key in repos:
                target_machine = machine
                break
        if target_machine is None:
            raise ValueError(f"No machine mapping found for repo '{repo_key}' in id '{line}'")
        assignments[target_machine].append(line)
        repo_counts_per_machine[target_machine][repo_key] += 1

    for machine in ["m1", "m2", "m3", "m4"]:
        out_path = Path(f"{args.output_prefix}.{machine}.txt")
        out_path.write_text("\n".join(assignments[machine]) + "\n", encoding="utf-8")

    print("Wrote split files:")
    for machine in ["m1", "m2", "m3", "m4"]:
        print(f"  - {args.output_prefix}.{machine}.txt: {len(assignments[machine])} instances")
        for repo_name, count in sorted(repo_counts_per_machine[machine].items()):
            print(f"      {repo_name}: {count}")


if __name__ == "__main__":
    main()
