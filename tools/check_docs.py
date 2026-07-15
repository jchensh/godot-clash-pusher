"""E0 documentation and agent-rule consistency gate (stdlib only)."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
BEGIN = "<!-- AGENT-SHARED:BEGIN -->"
END = "<!-- AGENT-SHARED:END -->"

REQUIRED_DOCS = (
    "docs/architecture/ONLINE_RUNTIME_CONTRACT.md",
    "docs/architecture/GATEWAY_STATE_MODEL.md",
    "docs/architecture/CONFIG_AUTHORITY.md",
    "docs/adr/0001-single-active-gateway.md",
    "docs/adr/0002-server-config-authority.md",
    "docs/adr/0003-offline-training-boundary.md",
    "docs/security/THREAT_MODEL.md",
    "docs/security/AUTH_AND_WS_TICKETS.md",
    "docs/deployment/STAGING.md",
    "docs/deployment/PRODUCTION_GATES.md",
    "docs/runbooks/GATEWAY_DRAIN.md",
    "docs/runbooks/ROLLBACK.md",
    "docs/runbooks/INCIDENT_RESPONSE.md",
    "docs/engineering/AGENT_SHARED_RULES.md",
)


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def shared_block(path: Path, failures: list[str]) -> str:
    text = path.read_text(encoding="utf-8")
    if text.count(BEGIN) != 1 or text.count(END) != 1:
        fail(f"{path.relative_to(ROOT)}: expected exactly one shared block", failures)
        return ""
    return text.split(BEGIN, 1)[1].split(END, 1)[0].strip()


def check_links(path: Path, failures: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for match in re.finditer(r"(?<!!)\[[^\]]+\]\(([^)]+)\)", text):
        raw = match.group(1).strip().strip("<>")
        if raw.startswith(("http://", "https://", "mailto:", "#")):
            continue
        target = unquote(raw.split("#", 1)[0])
        if not target:
            continue
        resolved = (path.parent / target).resolve()
        if not resolved.exists():
            line = text.count("\n", 0, match.start()) + 1
            fail(f"{path.relative_to(ROOT)}:{line}: missing link target {raw}", failures)


def main() -> int:
    failures: list[str] = []

    for relative in REQUIRED_DOCS:
        path = ROOT / relative
        if not path.is_file():
            fail(f"missing required E0 document: {relative}", failures)

    agent = shared_block(ROOT / "AGENTS.md", failures)
    claude = shared_block(ROOT / "CLAUDE.md", failures)
    if agent and claude and agent != claude:
        fail("AGENTS.md and CLAUDE.md shared blocks differ", failures)

    required_pointer = "docs/engineering/AGENT_SHARED_RULES.md"
    if required_pointer not in agent:
        fail("shared block does not point to the shared rule source", failures)

    files_to_check = [ROOT / name for name in REQUIRED_DOCS]
    files_to_check += [ROOT / name for name in ("AGENTS.md", "CLAUDE.md", "PLAN_GRAND.md", "PLAN_V5.md")]
    for path in files_to_check:
        if path.is_file():
            check_links(path, failures)

    if failures:
        print("documentation checks failed:")
        for item in failures:
            print(f"- {item}")
        return 1

    print(f"documentation checks passed ({len(files_to_check)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
