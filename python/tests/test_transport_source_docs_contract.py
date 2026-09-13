from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRIBUTING = ROOT / "CONTRIBUTING.md"
ARCHITECTURE = (
    ROOT
    / "Sources"
    / "OpenAPITransportKit"
    / "Documentation.docc"
    / "Architecture.md"
)

UNQUALIFIED_CLOSED_ENUM_RULE = (
    "- Prefer protocol-based extension points over closed enums.\n"
)


def _api_rules(text: str) -> str:
    return text.split("## API Rules", 1)[1].split("## ", 1)[0]


def test_contributing_excepts_closed_transport_source() -> None:
    text = CONTRIBUTING.read_text(encoding="utf-8")
    rules = _api_rules(text)
    assert UNQUALIFIED_CLOSED_ENUM_RULE not in text
    assert "TransportSource" in rules
    assert "TransportSelector" in rules
    lowered = rules.lower()
    assert "closed" in lowered
    assert "string-keyed" in lowered


def test_architecture_routes_custom_selection_through_transport_selector() -> None:
    text = ARCHITECTURE.read_text(encoding="utf-8")
    assert "Custom selection belongs in" in text
    assert "TransportSelector" in text
    assert "string-keyed" in text
