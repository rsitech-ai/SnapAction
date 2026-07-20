## Summary

Describe the bounded change and why it is needed.

## Verification

- [ ] `swift test`
- [ ] `swift build -c release`
- [ ] `bash script/test_build_configuration.sh`
- [ ] `bash script/test_bundle_metadata.sh`
- [ ] `bash script/test_release_package.sh`
- [ ] `python3 -m unittest discover -s Tests/ToolingTests -v`
- [ ] `python3 script/check_repository_policy.py`
- [ ] No private OCR, clipboard, account, credential, signing, or filesystem data is included.

## Contribution certification

- [ ] Every contribution commit includes a DCO `Signed-off-by` trailer.
- [ ] I agree that my contribution is submitted under Apache-2.0.
