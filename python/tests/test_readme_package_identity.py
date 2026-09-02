from pathlib import Path
import re

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


def test_git_install_is_pinned_to_first_release() -> None:
    for document in (README, GETTING_STARTED):
        text = document.read_text(encoding="utf-8")
        install_fences = [fence for fence in _swift_fences(text) if GIT_URL in fence]
        assert install_fences
        for fence in install_fences:
            assert 'from: "0.1.0"' in fence
            assert 'branch: "main"' not in fence


def test_mill_state_is_ignored_and_untracked() -> None:
    gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8").splitlines()
    assert ".lokay/" in gitignore
    assert not (ROOT / ".lokay").exists()
