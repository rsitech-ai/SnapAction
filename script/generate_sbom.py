#!/usr/bin/env python3
"""Generate a deterministic CycloneDX SBOM for the SnapAction source package."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import uuid

from publication_evidence import SBOM_PATH, build_manifest, canonical_json_bytes, write_json


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=SBOM_PATH)
    return parser.parse_args()


def property_value(name: str, value: str) -> dict[str, str]:
    return {"name": name, "value": value}


def build_sbom() -> dict:
    manifest = build_manifest()
    application = manifest["application"]
    target_components = [
        {
            "bom-ref": f"internal:{target}",
            "name": target,
            "properties": [
                property_value("snapaction.relationship", "internal-source-target"),
                property_value("snapaction.redistributed", "true"),
            ],
            "scope": "required",
            "type": "application" if target == "SnapActionApp" else "library",
            "version": application["version"],
        }
        for target in application["source_targets"]
    ]
    framework_components = [
        {
            "bom-ref": f"apple-framework:{framework}",
            "name": framework,
            "properties": [
                property_value("snapaction.relationship", "provided-by-platform"),
                property_value("snapaction.redistributed", "false"),
            ],
            "scope": "required",
            "type": "framework",
        }
        for framework in manifest["dependencies"]["apple_system_frameworks"]
    ]
    components = sorted(target_components + framework_components, key=lambda component: component["bom-ref"])
    seed = hashlib.sha256(
        canonical_json_bytes(
            {
                "application": application,
                "components": components,
                "evidence_inputs": manifest["evidence_inputs"],
            }
        )
    ).hexdigest()
    dependencies = [
        {
            "dependsOn": sorted(
                ["internal:SnapActionCore"]
                + [component["bom-ref"] for component in framework_components]
            ),
            "ref": "internal:SnapActionApp",
        },
        {"dependsOn": ["apple-framework:Foundation"], "ref": "internal:SnapActionCore"},
    ]
    return {
        "bomFormat": "CycloneDX",
        "components": components,
        "dependencies": dependencies,
        "metadata": {
            "component": {
                "bom-ref": "application:SnapAction",
                "name": application["name"],
                "properties": [
                    property_value("snapaction.build-system", application["build_system"]),
                    property_value("snapaction.platform", application["platform"]),
                ],
                "type": "application",
                "version": application["version"],
            },
            "tools": {
                "components": [
                    {
                        "bom-ref": "build-tool:Swift",
                        "name": "Swift",
                        "properties": [property_value("snapaction.relationship", "build-tool")],
                        "type": "application",
                        "version": manifest["toolchain"]["swift_tools_version"],
                    }
                ]
            },
        },
        "properties": [
            property_value(
                "snapaction.external-swift-package-count",
                str(manifest["dependencies"]["external_swift_package_count"]),
            )
        ],
        "serialNumber": f"urn:uuid:{uuid.uuid5(uuid.NAMESPACE_URL, 'snapaction-sbom:' + seed)}",
        "specVersion": "1.6",
        "version": 1,
    }


def main() -> int:
    arguments = parse_arguments()
    write_json(build_sbom(), arguments.output.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
