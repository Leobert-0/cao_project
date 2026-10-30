"""Inject one arithmetic fault into a build copy to verify assertion exit status."""
from pathlib import Path
import os
import shutil
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
os.chdir(root)
build=root/'.build'
build.mkdir(exist_ok=True)
original=(root/'rtl/behavioral.v').read_text()
needle="extended={1'b0,a}+{1'b0,b};"
assert original.count(needle)==1
mutant=build/'behavioral_fault.v'
mutant.write_text(original.replace(needle,"extended={1'b0,a}+{1'b0,b}+1'b1;"))
compiler=shutil.which('iverilog') or str(Path(os.environ.get('LOCALAPPDATA',''))/'cao-hdl-tools/iverilog/bin/iverilog.exe')
runtime=shutil.which('vvp') or str(Path(compiler).with_name('vvp.exe'))
exe=build/'fault.vvp'
subprocess.run([compiler,'-g2012','-Irtl','-s','tb_alu','-Ptb_alu.WIDTH=4','-o',str(exe),
                'rtl/structural.v',str(mutant),'tb/tb_alu.v'],check=True)
result=subprocess.run([runtime,str(exe)],capture_output=True,text=True)
(root/'results/fault_detection.log').write_text(result.stdout+result.stderr)
if result.returncode==0 or '[FAIL]' not in result.stdout:
    raise SystemExit('FAIL: injected arithmetic bug was not rejected')
print('PASS: injected ADD +1 fault rejected with nonzero simulation exit status.')
