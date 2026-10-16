"""Include fixed-width integer types explicitly in RmlUi's hash container.

Recent C++ standard library headers no longer supply <cstdint> transitively.
Keep this submodule fix reproducible after a fresh checkout or update.
"""

from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TARGET = REPO / "lib/RecompFrontend/recompui/lib/RmlUi/Include/RmlUi/Core/Containers/robin_hood.h"


def main():
    if not TARGET.is_file():
        raise SystemExit(f"missing {TARGET}\nRun: git submodule update --init --recursive")
    text = TARGET.read_text(encoding="utf-8")
    if "#include <cstdint>" in text:
        print(f"  {TARGET.name} already patched")
        return
    anchor = "#include <limits>"
    if anchor not in text:
        raise SystemExit(f"anchor not found in {TARGET}; revisit this patch")
    TARGET.write_text(text.replace(anchor, "#include <cstdint>\n" + anchor, 1), encoding="utf-8")
    print(f"  {TARGET.name} patched")


if __name__ == "__main__":
    main()
