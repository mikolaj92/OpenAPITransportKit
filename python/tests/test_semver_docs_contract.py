from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
README = ROOT / "README.md"
CONTRIBUTING = ROOT / "CONTRIBUTING.md"
RELEASE = ROOT / "RELEASE.md"
API_DESIGN = (
    ROOT
    / "Sources"
    / "OpenAPITransportKit"
    / "Documentation.docc"
    / "APIDesign.md"
)

BEFORE_1_0_BREAKING = (
    "Before `1.0.0`, source-breaking changes are allowed when they "
    "simplify the long-term API."
)


def _normalized(text: str) -> str:
    return re.sub(r"\s+", " ", text)


def test_readme_contributing_release_and_apidesign_share_pre_1_0_breaking_sentence() -> None:
    for path in (README, CONTRIBUTING, RELEASE, API_DESIGN):
        text = _normalized(path.read_text(encoding="utf-8"))
        assert BEFORE_1_0_BREAKING in text, (
            f"{path.relative_to(ROOT)} must use the shared pre-1.0 breaking sentence"
        )


def test_release_policy_describes_semver_0_x() -> None:
    text = RELEASE.read_text(encoding="utf-8")
    intro = text.split("## Swift Baseline", 1)[0]
    normalized = _normalized(intro)
    assert BEFORE_1_0_BREAKING in normalized
    assert "`0.y.z`" in intro
    assert "source-breaking" in intro


def test_release_patch_minor_major_table_applies_after_1_0() -> None:
    text = RELEASE.read_text(encoding="utf-8")
    versioning = text.split("## Versioning", 1)[1].split("## ", 1)[0]
    after_pos = versioning.find("After `1.0.0`")
    patch_pos = versioning.find("- Patch:")
    minor_pos = versioning.find("- Minor:")
    major_pos = versioning.find("- Major:")
    assert after_pos != -1, "Versioning table must be annotated as after 1.0.0"
    assert patch_pos != -1 and minor_pos != -1 and major_pos != -1
    assert after_pos < patch_pos < minor_pos < major_pos
