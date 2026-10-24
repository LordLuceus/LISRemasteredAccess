"""Summarize isolated named-target tests without equating arrival with usability."""
import argparse
import json
import re
from pathlib import Path


def fields(line):
    matches = list(re.finditer(r"(?:^|\s)([A-Za-z_]\w*)=", line))
    return {
        match.group(1): line[match.end():matches[i + 1].start() if i + 1 < len(matches) else None].strip()
        for i, match in enumerate(matches)
    }


def summarize(log):
    out = {"path": None, "walk_result": None, "snapshots": [], "collision_hits": [], "errors": []}
    for raw in log.splitlines():
        if "[LISNavTick] " not in raw:
            continue
        line = raw.split("[LISNavTick] ", 1)[1]
        data = fields(line)
        if line.startswith("target_path "):
            out["path"] = data
        elif line.startswith("follow_end="):
            out["walk_result"] = data["follow_end"]
        elif line.startswith("target_snapshot "):
            data["focus_matches_target"] = data.get("focused", "").endswith("." + data.get("target", "<missing>"))
            out["snapshots"].append(data)
        elif line.startswith("collision_hit "):
            out["collision_hits"].append(data)
        elif any(key == "error" or (key.endswith("_error") and key != "end_error") for key in data):
            out["errors"].append(line)
    out["walk_arrived"] = out["walk_result"] == "arrived_test_region"
    # Deliberately no overall PASS: focus, native actionable lists and actual
    # activation are separate evidence, and activation is not tested here.
    out["activation_tested"] = False
    return out


def self_test():
    s = summarize("[LISNavTick] target_path valid=true partial=false points=6\n"
                  "[LISNavTick] follow_end=stalled stop_ok=true")
    assert s["path"]["valid"] == "true" and not s["walk_arrived"]
    s = summarize("[LISNavTick] follow_end=arrived_test_region stop_ok=true\n"
                  "[LISNavTick] target_snapshot phase=settled target=Bottle inner=false focused=none current=none")
    assert s["walk_arrived"] and not s["snapshots"][0]["focus_matches_target"]
    assert not s["activation_tested"]
    s = summarize("[LISNavTick] target_snapshot phase=settled target=Bottle inner=true focused=LiSInteractionActor /Game/Map.Level.Bottle current=none")
    assert s["snapshots"][0]["focus_matches_target"]
    assert s["snapshots"][0]["focused"].startswith("LiSInteractionActor /Game/")
    s = summarize("[LISNavTick] native_path=1 valid=true end_error=0\n"
                  "[LISNavTick] route_error=invalid wrapper")
    assert len(s["errors"]) == 1 and s["errors"][0].startswith("route_error=")
    print("4 parser checks passed; arrival, focus and activation remain separate")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sessions", nargs="*", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    for directory in args.sessions:
        report = summarize((directory / "UE4SS.log").read_text(encoding="utf-8-sig"))
        report["session"] = directory.name
        result = directory / "result.json"
        report["profile_and_exit"] = json.loads(result.read_text(encoding="utf-8-sig")) if result.exists() else None
        print(json.dumps(report, indent=2))
