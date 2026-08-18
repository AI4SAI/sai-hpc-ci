import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parents[1] / "controller"))
from validate_plan import validate
def base():
    return {"version": 1, "cluster_profile": "sai-cuda12-openmpi5", "source": {"repository": "AI4SAI/demo", "sha": "a" * 40}, "tests": [{"name": "unit", "command": ["ctest", "--output-on-failure"]}]}
def test_valid_plan(): assert validate(base())["tests"][0]["name"] == "unit"
def test_rejects_path_escape():
    p = base(); p["tests"][0]["working_directory"] = "../../host"
    try: validate(p)
    except ValueError: return
    assert False
def test_allows_container_shell_argument():
    p = base(); p["tests"][0]["command"] = ["sh", "-c", "echo ok; id"]
    assert validate(p)["tests"][0]["command"][-1] == "echo ok; id"
