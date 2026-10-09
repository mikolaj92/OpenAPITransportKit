from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
README = ROOT / "README.md"
GETTING_STARTED = (
    ROOT
    / "Sources"
    / "OpenAPITransportKit"
    / "Documentation.docc"
    / "GettingStarted.md"
)
PACKAGE_SWIFT = ROOT / "Package.swift"

GIT_URL = "https://github.com/mikolaj92/OpenAPITransportKit.git"
WRONG_PACKAGE = 'package: "swift-openapi-transport-kit"'
RIGHT_PACKAGE = 'package: "OpenAPITransportKit"'

# SwiftPM's `from:` and `exact:` requirements take SemVer versions. Keep this
# contract version-agnostic so a new release does not require a test change.
_SEMVER_IDENTIFIER = (
    r"(?:0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)"
)
SEMVER_PATTERN = (
    rf"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
    rf"(?:-{_SEMVER_IDENTIFIER}(?:\.{_SEMVER_IDENTIFIER})*)?"
    rf"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)
PINNED_VERSION = re.compile(rf'(?:from|exact):\s*"{SEMVER_PATTERN}"')


def _swift_fences(text: str) -> list[str]:
    return re.findall(r"```swift\n(.*?)```", text, flags=re.S)


def _assert_git_product_uses_url_identity(text: str) -> None:
    fences = _swift_fences(text)
    assert any(GIT_URL in fence for fence in fences)
    product_fences = [fence for fence in fences if ".product(" in fence]
    assert product_fences
    for fence in product_fences:
        assert RIGHT_PACKAGE in fence
        assert WRONG_PACKAGE not in fence


def test_readme_git_install_uses_url_package_identity() -> None:
    _assert_git_product_uses_url_identity(README.read_text(encoding="utf-8"))


def test_getting_started_git_install_uses_url_package_identity() -> None:
    _assert_git_product_uses_url_identity(GETTING_STARTED.read_text(encoding="utf-8"))


def test_package_swift_keeps_path_dependency_name() -> None:
    manifest = PACKAGE_SWIFT.read_text(encoding="utf-8")
    assert 'name: "swift-openapi-transport-kit"' in manifest


def test_git_install_is_pinned_to_a_semver_release() -> None:
    for document in (README, GETTING_STARTED):
        text = document.read_text(encoding="utf-8")
        install_fences = [fence for fence in _swift_fences(text) if GIT_URL in fence]
        assert install_fences
        for fence in install_fences:
            assert PINNED_VERSION.search(fence), (
                "Git installs must use from: or exact: with a SemVer version"
            )
            assert 'branch: "main"' not in fence


def test_mill_state_is_ignored_and_untracked() -> None:
    gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8").splitlines()
    assert ".lokay/" in gitignore
    # The Lokay mill runs from a checkout and keeps state in `.lokay/`, so the
    # directory may exist. The contract is that it stays gitignored and never
    # tracked, not that it is absent.
    ignored = subprocess.run(
        ["git", "check-ignore", "-q", "--", ".lokay/"],
        cwd=ROOT,
        capture_output=True,
        check=False,
    )
    assert ignored.returncode == 0, ".lokay/ must be gitignored"
    tracked = subprocess.run(
        ["git", "ls-files", "--error-unmatch", "--", ".lokay"],
        cwd=ROOT,
        capture_output=True,
        check=False,
    )
    assert tracked.returncode != 0, ".lokay/ must not be tracked by git"
