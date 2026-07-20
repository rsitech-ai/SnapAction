#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
python3 -m unittest \
  Tests.ToolingTests.test_publication_tools.PublicationToolTests.test_release_packager_builds_verified_zip_and_checksum_without_distribution_claims \
  Tests.ToolingTests.test_publication_tools.PublicationToolTests.test_release_packager_rejects_a_dirty_source_tree \
  -v
