extends RefCounted
## Overwritten at export time by .github/workflows/windows-build.yml.
## Source checkouts correctly report that they are not reproducible CI exports.
const SOURCE_REVISION = "source-checkout"
const BUILD_FLAVOR = "local-development"
