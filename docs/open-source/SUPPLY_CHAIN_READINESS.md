# Supply-chain readiness

The repository declares zero external Swift packages. `artifacts/sbom/snapaction.cdx.json` is a deterministic CycloneDX 1.6 source-package SBOM covering the application, internal Swift targets, Swift build tool, and Apple system frameworks. Apple frameworks are marked platform-provided and not redistributed.

Regenerate and verify evidence with:

```sh
python3 script/generate_open_source_manifest.py
python3 script/generate_sbom.py
python3 -m json.tool docs/open-source/OPEN_SOURCE_MANIFEST.json >/dev/null
python3 -m json.tool artifacts/sbom/snapaction.cdx.json >/dev/null
python3 -m unittest discover -s Tests/ToolingTests -v
```

The SBOM proves only the repository-derived dependency inventory captured by the generator. It is not a notarization record, binary attestation, vulnerability scan, or legal conclusion.
