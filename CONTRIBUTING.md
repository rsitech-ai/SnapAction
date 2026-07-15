# Contributing

External contributions are not yet accepted.

The repository does not currently have an owner-approved license, contributor certificate, public governance model, maintainer roster, trademark policy, or private security-reporting channel. Until those decisions are recorded, do not submit code, documentation, translations, designs, or other copyrightable material for inclusion. Opening an issue or pull request does not grant acceptance or licensing authority.

Repository collaborators working under separate authority should keep changes focused, avoid private data, and run:

```sh
swift test
swift build -c release
bash script/test_build_configuration.sh
python3 -m unittest discover -s Tests/ToolingTests -v
python3 script/check_repository_policy.py
```

Do not add `Signed-off-by` trailers or claim DCO/CLA coverage: neither model has been adopted. See `docs/open-source/GOVERNANCE_REVIEW.md` and `docs/open-source/LICENSE_MAP.md` for the unresolved decisions.

Do not disclose vulnerabilities in issues or pull requests. There is no approved private intake channel yet, so retain details privately until the project publishes one.
