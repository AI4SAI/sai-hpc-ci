#!/usr/bin/env python3
"""Trusted Slurm array entrypoint; the project command runs only in Apptainer."""
import json, os, pathlib, shutil, stat, subprocess, sys
import tarfile

def extract_source(archive, destination):
    with tarfile.open(archive, "r:gz") as tar:
        members = tar.getmembers()
        if len(members) > 100000:
            raise ValueError("source archive has too many members")
        for member in members:
            path = pathlib.PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts or member.issym() or member.islnk():
                raise ValueError("unsafe source archive member")
        tar.extractall(destination, filter="data")

def main():
    plan = json.load(open(os.environ["PLAN_FILE"], encoding="utf-8"))
    task = plan["tests"][int(os.environ.get("SLURM_ARRAY_TASK_ID", "0"))]
    task_id = f"{os.environ.get('SLURM_JOB_ID','manual')}-{os.environ.get('SLURM_ARRAY_TASK_ID','0')}"
    root = pathlib.Path(os.environ["REMOTE_ROOT"]) / "work" / task_id
    final_results = pathlib.Path(os.environ["REMOTE_ROOT"]) / "results" / task_id
    source, build, scratch_results, tmp = root / "source", root / "build", root / "results", root / "tmp"
    for path in (source, build, scratch_results, tmp, final_results): path.mkdir(parents=True, exist_ok=True)
    try:
        extract_source(os.environ["SOURCE_ARCHIVE"], source)
        profile = {}
        for line in open(os.environ["PROFILE_FILE"], encoding="utf-8"):
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.strip().split("=", 1); profile[key] = value.strip('"')
        env = os.environ.copy()
        env.update({"HOME": "/tmp", "SOURCE_DATE_EPOCH": "0"})
        image = os.environ.get("ROOTFS", profile["ROOTFS"])
        workdir = pathlib.PurePosixPath("/workspace/source") / task["working_directory"]
        container_cmd = ["apptainer", "exec", "--cleanenv", "--containall", "--no-home", "--bind", f"{source}:/workspace/source:ro", "--bind", f"{build}:/workspace/build:rw", "--bind", f"{scratch_results}:/workspace/results:rw", "--bind", f"{tmp}:/tmp:rw", "--bind", "/opt:/opt:ro", "--bind", "/usr:/usr:ro", "--bind", "/lib:/lib:ro", "--bind", "/lib64:/lib64:ro", "--bind", f"{profile['MPI_ROOT']}:{profile['MPI_ROOT']}:ro", image, "/bin/sh", "-c", "cd \"$1\" && shift && exec \"$@\"", "sh", str(workdir), *task["command"]]
        launch = ["mpirun", "-np", str(task["nodes"] * task["ranks_per_node"]), "--map-by", os.environ["MAP_OPT"]]
        with open(final_results / "stdout.log", "wb") as log:
            completed = subprocess.run(launch + container_cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=task["timeout_minutes"] * 60)
        for candidate in scratch_results.rglob("*"):
            relative = candidate.relative_to(scratch_results)
            info = candidate.lstat()
            if stat.S_ISREG(info.st_mode) and info.st_size <= 100 * 1024 * 1024:
                destination = final_results / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(candidate, destination, follow_symlinks=False)
        with open(final_results / "result.json", "w", encoding="utf-8") as handle:
            json.dump({"name": task["name"], "returncode": completed.returncode}, handle)
        return completed.returncode
    finally:
        shutil.rmtree(root, ignore_errors=True)
if __name__ == "__main__": raise SystemExit(main())
