"""
Batch build, push, and clean Docker images for SWE-Gym instances.

Groups instances by env image to maximize cache reuse, pushes each batch
to a container registry, then removes instance images to reclaim disk.
Maintains a state file for resumability across interruptions.
"""

from __future__ import annotations

import json
import subprocess
import resource
import traceback
from argparse import ArgumentParser
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import docker
from tqdm import tqdm

from swebench.harness.docker_build import (
    build_base_images,
    build_env_images,
    build_instance_image,
    BuildImageError,
)
from swebench.harness.docker_utils import remove_image, list_images
from swebench.harness.test_spec import make_test_spec
from swebench.harness.utils import load_swebench_dataset


def load_instance_ids(path: str) -> list[str]:
    return [line.strip() for line in Path(path).read_text().splitlines() if line.strip()]


def load_state(state_path: Path) -> dict:
    if state_path.exists():
        return json.loads(state_path.read_text())
    return {"pushed": [], "failed": []}


def save_state(state_path: Path, state: dict):
    state_path.write_text(json.dumps(state, indent=2))


def push_image(client: docker.DockerClient, local_tag: str, registry_tag: str) -> bool:
    """Tag a local image and push it to the registry. Returns True on success."""
    try:
        image = client.images.get(local_tag)
        image.tag(registry_tag)
        print(f"  Pushing {registry_tag} ...")
        result = subprocess.run(
            ["docker", "push", registry_tag],
            capture_output=True,
            text=True,
            timeout=1800,
        )
        if result.returncode != 0:
            print(f"  Push failed for {registry_tag}: {result.stderr.strip()}")
            return False
        print(f"  Pushed {registry_tag}")
        return True
    except Exception as e:
        print(f"  Error pushing {registry_tag}: {e}")
        return False


def make_registry_tag(registry: str, local_tag: str) -> str:
    """Convert local image tag to a registry tag.

    Format: <registry>:<image_name_as_tag>
    e.g. gitlab:5005/user/project/swe-gym:sweb.eval.arm64.getmoto__moto-7365
    """
    # local_tag is like "sweb.eval.arm64.getmoto__moto-7365:latest"
    name = local_tag.replace(":latest", "")
    return f"{registry}:{name}"


def main(
    dataset: str,
    split: str,
    instance_ids_file: str,
    registry: str,
    max_workers: int,
    push_env_images: bool,
    force_rebuild: bool,
    open_file_limit: int,
    state_file: str,
    dry_run: bool,
):
    resource.setrlimit(resource.RLIMIT_NOFILE, (open_file_limit, open_file_limit))
    client = docker.from_env()

    state_path = Path(state_file)
    state = load_state(state_path)
    pushed_set = set(state["pushed"])

    # Load dataset and filter to requested instance IDs
    instance_ids = load_instance_ids(instance_ids_file)
    print(f"Loaded {len(instance_ids)} instance IDs from {instance_ids_file}")

    all_instances = load_swebench_dataset(dataset, split=split)
    instance_map = {inst["instance_id"]: inst for inst in all_instances}

    # Filter to only requested IDs that exist in the dataset
    missing = [iid for iid in instance_ids if iid not in instance_map]
    if missing:
        print(f"Warning: {len(missing)} instance IDs not found in dataset, skipping them.")
        if len(missing) <= 10:
            for m in missing:
                print(f"  - {m}")

    instances = [instance_map[iid] for iid in instance_ids if iid in instance_map]
    print(f"Found {len(instances)} instances in dataset")

    # Build test specs and group by env image
    specs = []
    for inst in instances:
        try:
            spec = make_test_spec(inst)
            specs.append((inst, spec))
        except Exception as e:
            print(f"Warning: Could not create test spec for {inst['instance_id']}: {e}")

    env_groups: dict[str, list[tuple]] = defaultdict(list)
    for inst, spec in specs:
        env_groups[spec.env_image_key].append((inst, spec))

    print(f"\nImage build plan:")
    print(f"  Total instances: {len(specs)}")
    print(f"  Unique env images: {len(env_groups)}")
    print(f"  Already pushed: {len(pushed_set)}")

    # Skip instances already pushed
    remaining = 0
    for env_key, group in env_groups.items():
        count = sum(1 for _, spec in group if spec.instance_id not in pushed_set)
        if count > 0:
            remaining += count
    print(f"  Remaining to build+push: {remaining}")

    if remaining == 0:
        print("\nAll instances already pushed. Nothing to do.")
        return

    if dry_run:
        print("\n[DRY RUN] Would process the following env groups:")
        for env_key, group in sorted(env_groups.items()):
            unpushed = [spec.instance_id for _, spec in group if spec.instance_id not in pushed_set]
            if unpushed:
                print(f"  {env_key}: {len(unpushed)} instances")
        return

    # Build base image first (shared by all)
    print("\n--- Building base images ---")
    build_base_images(client, [inst for inst, _ in specs], force_rebuild)

    # Process each env group: build env -> build instances -> push -> clean
    total_groups = len([g for g in env_groups.values() if any(s.instance_id not in pushed_set for _, s in g)])
    group_idx = 0

    for env_key, group in sorted(env_groups.items()):
        unpushed = [(inst, spec) for inst, spec in group if spec.instance_id not in pushed_set]
        if not unpushed:
            continue

        group_idx += 1
        print(f"\n{'='*60}")
        print(f"Env group {group_idx}/{total_groups}: {env_key}")
        print(f"  Instances to build: {len(unpushed)}")
        print(f"{'='*60}")

        # Build env image for this group
        print(f"\n  Building env image: {env_key}")
        sample_inst, sample_spec = unpushed[0]
        try:
            build_env_images(client, [sample_inst], force_rebuild, max_workers=1)
        except Exception as e:
            print(f"  FAILED to build env image {env_key}: {e}")
            for _, spec in unpushed:
                state["failed"].append(spec.instance_id)
            save_state(state_path, state)
            continue

        # Build instance images for this group in parallel
        built_specs = []
        failed_specs = []
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(build_instance_image, spec, client, None, False): spec
                for _, spec in unpushed
            }
            pbar = tqdm(
                as_completed(futures), total=len(futures),
                desc=f"  Build ({env_key})", unit="img",
            )
            for future in pbar:
                spec = futures[future]
                try:
                    future.result()
                    built_specs.append(spec)
                except BuildImageError as e:
                    tqdm.write(f"  FAILED to build {spec.instance_id}: {e}")
                    failed_specs.append(spec)
                except Exception as e:
                    tqdm.write(f"  FAILED to build {spec.instance_id}: {e}")
                    traceback.print_exc()
                    failed_specs.append(spec)
        for spec in failed_specs:
            state["failed"].append(spec.instance_id)
        if failed_specs:
            save_state(state_path, state)

        # Push instance images
        for spec in tqdm(built_specs, desc=f"  Push  ({env_key})", unit="img"):
            local_tag = spec.instance_image_key
            registry_tag = make_registry_tag(registry, local_tag)
            success = push_image(client, local_tag, registry_tag)
            if success:
                state["pushed"].append(spec.instance_id)
                pushed_set.add(spec.instance_id)
            else:
                state["failed"].append(spec.instance_id)
            save_state(state_path, state)

        # Clean instance images to reclaim disk
        for spec in tqdm(built_specs, desc=f"  Clean ({env_key})", unit="img"):
            try:
                remove_image(client, spec.instance_image_key, "quiet")
            except Exception:
                pass

        print(f"  Group complete. Total pushed so far: {len(state['pushed'])}")

    # Optionally push env + base images
    if push_env_images:
        print(f"\n{'='*60}")
        print("Pushing env and base images...")
        print(f"{'='*60}")
        existing = list_images(client)
        for tag in sorted(existing):
            if tag.startswith("sweb.env.") or tag.startswith("sweb.base."):
                registry_tag = make_registry_tag(registry, tag)
                push_image(client, tag, registry_tag)

    # Final summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    print(f"  Total pushed: {len(state['pushed'])}")
    print(f"  Total failed: {len(state['failed'])}")
    print(f"  State saved to: {state_path}")


if __name__ == "__main__":
    parser = ArgumentParser(description="Batch build, push, and clean SWE-Gym Docker images")
    parser.add_argument(
        "--dataset", type=str, required=True,
        help="Path to dataset .jsonl file or HuggingFace dataset name",
    )
    parser.add_argument(
        "--split", type=str, default="train",
        help="Dataset split to use (default: train)",
    )
    parser.add_argument(
        "--instance_ids_file", type=str, required=True,
        help="Path to file with instance IDs (one per line)",
    )
    parser.add_argument(
        "--registry", type=str, required=True,
        help="Registry path (e.g., registry.gitlab.com/user/project/train/swe-gym)",
    )
    parser.add_argument(
        "--max_workers", type=int, default=4,
        help="Max parallel workers for building images",
    )
    parser.add_argument(
        "--push_env_images", action="store_true",
        help="Also push env and base images to the registry at the end",
    )
    parser.add_argument(
        "--force_rebuild", action="store_true",
        help="Force rebuild images even if they exist locally",
    )
    parser.add_argument(
        "--open_file_limit", type=int, default=8192,
        help="Open file limit",
    )
    parser.add_argument(
        "--state_file", type=str, default="build_push_state.json",
        help="Path to state file for resumability",
    )
    parser.add_argument(
        "--dry_run", action="store_true",
        help="Show what would be built/pushed without actually doing it",
    )
    args = parser.parse_args()
    main(**vars(args))
