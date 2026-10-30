"""Entry point for a locally extracted YoWASP distribution."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.tools/yosys'))
import yowasp_yosys
sys.exit(yowasp_yosys.run_yosys(sys.argv[1:]))
