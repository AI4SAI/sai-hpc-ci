#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, posixpath, re, sys
from pathlib import PurePosixPath

PROFILES = {"sai-cuda12-openmpi5": {"max_nodes": 2, "max_gpus_per_node": 8, "max_ranks_per_node": 8, "max_timeout_minutes": 300}}
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")

def fail(message): raise ValueError(message)
def relative_path(value, field):
    if not isinstance(value, str) or not value or "\\" in value: fail(f"{field} must be a POSIX relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or value.startswith("~"): fail(f"{field} escapes the task workspace")
    return posixpath.normpath(value)
def command(value, field):
    if not isinstance(value, list) or not value or any(not isinstance(x, str) or not x for x in value): fail(f"{field} must be a non-empty string array")
    # Commands are passed as argv to subprocess/srun; shell metacharacters are
    # therefore data, not host-side syntax. NUL is the only impossible argv byte.
    if any("\x00" in x for x in value): fail(f"{field} contains NUL")
    return value
def validate(raw):
    if not isinstance(raw, dict) or raw.get("version") != 1: fail("plan version must be 1")
    profile_name = raw.get("cluster_profile")
    if profile_name not in PROFILES: fail("unknown cluster_profile")
    source = raw.get("source")
    if not isinstance(source, dict): fail("source is required")
    repository, sha = source.get("repository"), source.get("sha")
    if not isinstance(repository, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository): fail("source.repository must be owner/name")
    if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-fA-F]{40}", sha): fail("source.sha must be a full commit SHA")
    tests = raw.get("tests")
    if not isinstance(tests, list) or not tests: fail("tests must be a non-empty array")
    limits, names, output = PROFILES[profile_name], set(), {"version": 1, "cluster_profile": profile_name, "source": {"repository": repository, "sha": sha.lower()}, "tests": []}
    for i, item in enumerate(tests):
        if not isinstance(item, dict): fail(f"tests[{i}] must be an object")
        name = item.get("name")
        if not isinstance(name, str) or not NAME_RE.fullmatch(name) or name in names: fail(f"tests[{i}].name is invalid or duplicated")
        names.add(name)
        values = {k: item.get(k, d) for k, d in (("nodes", 1), ("gpus_per_node", 1), ("ranks_per_node", 1), ("timeout_minutes", 60))}
        for field, value, limit in (("nodes", values["nodes"], limits["max_nodes"]), ("gpus_per_node", values["gpus_per_node"], limits["max_gpus_per_node"]), ("ranks_per_node", values["ranks_per_node"], limits["max_ranks_per_node"]), ("timeout_minutes", values["timeout_minutes"], limits["max_timeout_minutes"])):
            if not isinstance(value, int) or value < 1 or value > limit: fail(f"tests[{i}].{field} exceeds profile limits")
        output["tests"].append({**values, "name": name, "working_directory": relative_path(item.get("working_directory", "."), f"tests[{i}].working_directory"), "command": command(item.get("command"), f"tests[{i}].command")})
    return output
def main():
    p = argparse.ArgumentParser(); p.add_argument("plan"); p.add_argument("--output", required=True); p.add_argument("--expected-repository"); p.add_argument("--expected-sha"); p.add_argument("--expected-profile"); args = p.parse_args()
    try:
        with open(args.plan, encoding="utf-8") as f: result = validate(json.load(f))
        if args.expected_repository and result["source"]["repository"] != args.expected_repository: fail("plan source does not match workflow source")
        if args.expected_sha and result["source"]["sha"] != args.expected_sha.lower(): fail("plan SHA does not match workflow SHA")
        if args.expected_profile and result["cluster_profile"] != args.expected_profile: fail("plan profile does not match workflow profile")
        with open(args.output, "w", encoding="utf-8") as f: json.dump(result, f, indent=2, sort_keys=True); f.write("\n")
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"plan validation failed: {exc}", file=sys.stderr); return 2
    return 0
if __name__ == "__main__": raise SystemExit(main())
