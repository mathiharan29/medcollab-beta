"""Exercise cold runtime provisioning and removal, without application tests."""

import json
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from test_vocle import remove_session, session_environment
from vocle_bootstrap import Bootstrap, checked

output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=False)
scratch = Path(tempfile.mkdtemp(prefix="vocle-python-"))
state = {"scope": "bootstrap-cold-downloads", "status": "ERROR"}
setup = Bootstrap(scratch, output, session_environment(scratch), state)
try:
    node = setup.node(force=True)
    assert Path(node).is_relative_to(scratch)
    assert checked([node, "--version"], env=setup.env)[1] == "v22.20.0"
    flutter = setup.flutter(force=True)
    assert Path(flutter).is_relative_to(scratch)
    version = json.loads(checked([flutter, "--version", "--machine"], env=setup.env)[1])
    assert version["frameworkVersion"] == "3.29.3"
    state["status"] = "PASS"
finally:
    setup.close()
    remove_session(scratch)
    state["temporaryDirectoryRemoved"] = not scratch.exists()
    (output / "validation.json").write_text(json.dumps(state, indent=2), encoding="utf-8")
print("Cold pinned Node/Flutter downloads, execution and cleanup PASS")
