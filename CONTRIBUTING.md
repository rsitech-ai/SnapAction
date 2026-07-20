# Contributing

SnapAction is maintained and released by [RSI Tech](https://rsitech.ai). Issues and focused pull requests are welcome.

By contributing, you agree that your contribution is submitted under the repository's [Apache License 2.0](LICENSE). Each commit must include a Developer Certificate of Origin sign-off:

```text
Signed-off-by: Your Name <your-email@example.com>
```

Create it with `git commit -s`. The sign-off certifies the [Developer Certificate of Origin 1.1](https://developercertificate.org/). Do not sign off work you do not have the right to contribute.

Before opening a pull request:

```sh
swift test
swift build -c release -Xswiftc -warnings-as-errors
bash script/test_build_configuration.sh
bash script/test_bundle_metadata.sh
bash script/test_release_package.sh
python3 -m unittest discover -s Tests/ToolingTests -v
python3 script/check_repository_policy.py
```

Keep changes focused, document user-visible behavior, and do not include private OCR or clipboard content, credentials, signing material, account data, or workstation paths. Maintainers may ask for a smaller patch or additional evidence before accepting a contribution.

Do not disclose vulnerabilities in issues or pull requests. Report them privately as described in [SECURITY.md](SECURITY.md).
