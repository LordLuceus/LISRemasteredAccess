"""Offline cooked-asset inventory/export; requires existing CUE4Parse binaries and .NET 10.

All machine paths are explicit CLI inputs. PNGs and helper build products belong
under an ignored private artifacts directory, never in a release or source tree.
Folder membership is candidate evidence, NOT proof of runtime use.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def canonical_id(value: str) -> str:
    """Convert cooked member, package, or full object path to a full object ID."""
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError("Asset path must be a nonempty, unpadded string")
    if "\\" in value or ".." in value or any(c.isspace() for c in value):
        raise ValueError("Invalid asset path")
    if value.lower().startswith("lis/content/"):
        value = "/Game/" + value[len("lis/content/"):]
    if not value.startswith("/Game/"):
        raise ValueError("Expected LiS/Content member or /Game asset path")
    if value.endswith(".umap"):
        raise ValueError("Map packages are not texture identities")
    if value.endswith(".uasset"):
        value = value[:-7]
    if not re.fullmatch(r"/Game/(?:[A-Za-z0-9_]+/)*[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)?", value):
        raise ValueError("Invalid package/object path")
    if "." not in value:
        value += "." + value.rsplit("/", 1)[-1]
    return value


def output_name(value: str) -> str:
    identity = canonical_id(value)
    # Full digest and a bounded readable suffix avoid same-basename collisions.
    return hashlib.sha256(identity.encode("utf-8")).hexdigest() + "-" + identity.rsplit(".", 1)[-1][:80] + ".png"


def unique_assets(values):
    """Deduplicate canonical identities without silently merging case conflicts."""
    result = {}
    folded = {}
    for value in values:
        identity = canonical_id(value)
        prior = folded.setdefault(identity.casefold(), identity)
        if prior != identity:
            raise ValueError(f"Case-ambiguous identities: {prior}, {identity}")
        result.setdefault(identity, value)
    names = [output_name(identity) for identity in result]
    if len(names) != len(set(names)):
        raise ValueError("Output filename collision")
    return dict(sorted(result.items()))


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def picture_actions(exports):
    """Retain actual serialized ShowPicture actions, not inferred filename links."""
    found = []

    def walk(value, pointer, owner):
        if isinstance(value, dict):
            if value.get("bShowPicture") is True:
                found.append({"export_name": owner.get("Name"), "export_type": owner.get("Type"),
                              "json_pointer": pointer, "action": value})
            for key, child in value.items():
                walk(child, pointer + "/" + key.replace("~", "~0").replace("/", "~1"), owner)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, pointer + "/" + str(index), owner)

    for index, owner in enumerate(exports):
        walk(owner, "/" + str(index), owner)
    return found


def run(command, log, env):
    completed = subprocess.run(command, capture_output=True, env=env,
                               creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    log.write_bytes(completed.stdout + completed.stderr)
    completed.check_returncode()


def main(argv=None):
    # Exclusive invocation guard prevents concurrent processes truncating shared
    # manifests/PNGs. The handle is released even if build/decode raises.
    output_parser = argparse.ArgumentParser(add_help=False)
    output_parser.add_argument("--output", type=Path)
    output_args, _ = output_parser.parse_known_args(argv)
    if output_args.output is None:
        return export_inventory(argv)
    output_args.output.mkdir(parents=True, exist_ok=True)
    lock_path = output_args.output / ".export.lock"
    try:
        lock = lock_path.open("x", encoding="utf-8")
    except FileExistsError:
        raise SystemExit(f"Export already active (or stale lock after interruption): {lock_path}")
    try:
        with lock:
            lock.write(str(os.getpid()))
            lock.flush()
            return export_inventory(argv)
    finally:
        lock_path.unlink()


def export_inventory(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--paks", required=True, type=Path)
    parser.add_argument("--indexes", required=True, type=Path)
    parser.add_argument("--dependencies", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--episode", default="Episode01")
    parser.add_argument("--inspect-list", type=Path, help="Bounded package member list for serialized reference evidence")
    args = parser.parse_args(argv)
    if not re.fullmatch(r"Episode0[1-5]", args.episode):
        parser.error("episode must be Episode01 through Episode05")
    for directory in (args.paks, args.indexes, args.dependencies):
        if not directory.is_dir():
            parser.error(f"Missing input directory: {directory}")
    args.output = args.output.resolve()
    args.dependencies = args.dependencies.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    png_dir = args.output / "png"
    png_dir.mkdir(exist_ok=True)
    provenance = defaultdict(list)
    index_hashes = {}
    for index in sorted(args.indexes.glob("*.index.txt")):
        index_hashes[index.name] = hashlib.sha256(index.read_bytes()).hexdigest()
        for member in index.read_text(encoding="utf-8-sig").splitlines():
            provenance[member].append(index.name.removesuffix(".index.txt") + ".pak")
    prefix = f"LiS/Content/Packages/ShowPicture/{args.episode}/"
    candidates = unique_assets(m for m in provenance if m.startswith(prefix) and m.endswith(".uasset"))
    if not candidates:
        parser.error("No candidate packages found in supplied indexes")
    requests = [{"member": member, "output": str(png_dir / output_name(identity)), "inspect": False}
                for identity, member in candidates.items()]
    if args.inspect_list:
        reference_dir = args.output / "references"
        reference_dir.mkdir(exist_ok=True)
        for member in sorted(set(args.inspect_list.read_text(encoding="utf-8").splitlines())):
            if not member:
                continue
            if member not in provenance:
                parser.error(f"Inspection member missing from indexes: {member}")
            digest = hashlib.sha256(member.encode()).hexdigest()
            requests.append({"member": member, "output": str(reference_dir / (digest + ".json")), "inspect": True})
    write_json(args.output / "requests.json", requests)
    env = os.environ.copy()
    env.update(DOTNET_CLI_HOME=str(args.output / "dotnet-home"), DOTNET_SKIP_FIRST_TIME_EXPERIENCE="1",
               DOTNET_CLI_TELEMETRY_OPTOUT="1", DOTNET_GENERATE_ASPNET_CERTIFICATE="false")
    project = Path(__file__).resolve().parents[1] / "tools/closeup-export/CloseupExport.csproj"
    build = args.output / "build"
    run(["dotnet", "build", str(project), "-c", "Release", "--nologo", "-p:NuGetAudit=false",
         f"-p:DependencyDir={args.dependencies}", f"-p:BaseIntermediateOutputPath={build / 'obj'}/",
         "-o", str(build / "bin")], args.output / "build.log", env)
    run(["dotnet", "exec", "--runtimeconfig", str(args.dependencies / "AnimExtract.runtimeconfig.json"),
         "--depsfile", str(args.dependencies / "AnimExtract.deps.json"), str(build / "bin/CloseupExport.dll"),
         str(args.paks.resolve()), str(args.output / "requests.json"), str(args.output / "results.jsonl")],
        args.output / "decode.log", env)
    results = [json.loads(line) for line in (args.output / "results.jsonl").read_text(encoding="utf-8").splitlines()]
    if len(results) != len(requests):
        raise RuntimeError("Incomplete helper results")
    rows, references = [], []
    for request, row in zip(requests, results):
        if row["member"] != request["member"]:
            raise RuntimeError("Helper result order mismatch")
        row["source_paks_from_indexes"] = sorted(set(provenance[row["member"]]))
        if request["inspect"]:
            row["evidence_file"] = str(Path(request["output"]).relative_to(args.output)).replace("\\", "/")
            if row["status"] == "inspected":
                evidence = Path(request["output"])
                row["evidence_sha256"] = hashlib.sha256(evidence.read_bytes()).hexdigest()
                row["picture_actions"] = picture_actions(json.loads(evidence.read_text(encoding="utf-8")))
            references.append(row)
            continue
        identity = canonical_id(row["member"])
        row["asset_path"] = identity.split(".")[0]
        row["object_path"] = row["asset_path"] + "." + row.get("object_name", identity.rsplit(".", 1)[-1])
        row["object_path_casefold"] = row["object_path"].casefold()
        row["source_evidence"] = "pak index folder candidate; helper export-type inspection"
        row["runtime_reference_status"] = "not_established"
        row["preview_name_hint"] = "preview" in row["member"].lower()
        if row["status"] == "decoded":
            row["png"] = "png/" + output_name(identity)
        rows.append(row)
    groups = defaultdict(list)
    for row in rows:
        if row["status"] == "decoded":
            groups[row["png_sha256"]].append(row["object_path"])
    manifest = {"schema_version": 1, "engine": "UE4.23 (installed UE4.23.1 cooked assets)",
                "scope": prefix, "coverage": "Folder candidates only; not complete Episode 1 runtime coverage",
                "source_index_sha256": index_hashes, "counts": dict(Counter(r["status"] for r in rows)),
                "png_bytes": sum(r.get("png_bytes", 0) for r in rows),
                "identical_png_groups": [ids for ids in groups.values() if len(ids) > 1],
                "assets": rows, "reference_inspections": references}
    manifest["dependency_sha256"] = {
        name: hashlib.sha256((args.dependencies / name).read_bytes()).hexdigest()
        for name in ("CUE4Parse.dll", "CUE4Parse-Conversion.dll", "SkiaSharp.dll")}
    write_json(args.output / "manifest.json", manifest)
    write_json(args.output / "invocation.json", {"argv": sys.argv if argv is None else argv})
    print(json.dumps({"counts": manifest["counts"], "png_bytes": manifest["png_bytes"],
                      "identical_png_groups": len(manifest["identical_png_groups"])}))
    return 1 if any(r["status"] == "failed" for r in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
