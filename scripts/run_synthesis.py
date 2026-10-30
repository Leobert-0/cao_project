"""Optional generic Yosys synthesis and post-synthesis simulation (no FPGA timing)."""
from pathlib import Path
import csv
import json
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
sys.path.insert(0, str(ROOT/'scripts'))

def main():
    native = shutil.which('yosys') or shutil.which('yowasp-yosys')
    if native:
        tool = [native]
    elif (ROOT/'.tools/yosys/yowasp_yosys').exists():
        # subprocess isolates each Yosys invocation; WASM retains only cwd access.
        tool = [sys.executable, str(ROOT/'scripts/yosys_entry.py')]
    else:
        raise SystemExit('Optional check: install yosys or pip install yowasp-yosys.')
    compiler = shutil.which('iverilog') or str(Path(os.environ.get('LOCALAPPDATA',''))/'cao-hdl-tools/iverilog/bin/iverilog.exe')
    runtime = shutil.which('vvp') or str(Path(compiler).with_name('vvp.exe'))
    subprocess.run([sys.executable,'scripts/generate_vectors.py'],check=True)
    results=[]
    for style in ('structural','behavioral'):
        dest=ROOT/'results/yosys'/style
        dest.mkdir(parents=True,exist_ok=True)
        rel=dest.relative_to(ROOT).as_posix()
        script=f'''read_verilog -Irtl rtl/structural.v rtl/behavioral.v rtl/demo_datapath.v
hierarchy -check -top alu_{style}
proc
select -assert-none t:$dlatch
synth -top alu_{style} -flatten -noabc
delete t:$scopeinfo
check -assert
select -assert-none t:$_DLATCH_*
tee -o {rel}/statistics.json stat -json
rename alu_{style} alu_netlist
write_verilog -noattr {rel}/netlist.v
'''
        (dest/'synthesis.ys').write_text(script)
        run=subprocess.run(tool+['-Q','-T','-s',f'{rel}/synthesis.ys'],capture_output=True,text=True)
        (dest/'synthesis.log').write_text(run.stdout+run.stderr)
        if run.returncode:
            print(run.stdout+run.stderr); return 1
        stats=json.loads((dest/'statistics.json').read_text())
        module=next(iter(stats['modules'].values()))
        # New and older Yosys versions use slightly different stat JSON keys.
        count=module.get('num_cells',module.get('num_cells_by_type',{}))
        if isinstance(count,dict): count=sum(count.values())
        netlist_exe=ROOT/'.build'/f'post_{style}.vvp'
        compile_run=subprocess.run([compiler,'-g2012','-s','tb_post','-o',str(netlist_exe),str(dest/'netlist.v'),'tb/tb_post.v'],capture_output=True,text=True)
        if compile_run.returncode:
            print(compile_run.stderr); return 1
        sim=subprocess.run([runtime,str(netlist_exe)],capture_output=True,text=True)
        (dest/'simulation.log').write_text(sim.stdout+sim.stderr)
        passed=sim.returncode==0 and '[PASS]' in sim.stdout
        results.append({'style':style,'generic_cells':count,'post_synthesis_passed':passed})
        print(f'{style}: generic cells={count}; post-synthesis {"PASS" if passed else "FAIL"}',flush=True)
        if not passed: print(sim.stdout+sim.stderr); return 1
    (ROOT/'results/yosys/comparison.json').write_text(json.dumps(results,indent=2)+'\n')
    lint_script='''read_verilog -Irtl rtl/structural.v rtl/behavioral.v rtl/demo_datapath.v
hierarchy -check -top demo_datapath
proc
select -assert-none t:$dlatch
check -assert
'''
    lint_path=ROOT/'results/yosys/demo_check.ys'
    lint_path.write_text(lint_script)
    lint=subprocess.run(tool+['-Q','-T','-s','results/yosys/demo_check.ys'],capture_output=True,text=True)
    (ROOT/'results/yosys/demo_check.log').write_text(lint.stdout+lint.stderr)
    if lint.returncode: print(lint.stderr); return 1
    print('Demo hierarchy, process conversion, latch rejection, and connectivity: PASS')
    with (ROOT/'results/yosys/comparison.csv').open('w',newline='') as file:
        writer=csv.DictWriter(file,fieldnames=list(results[0])); writer.writeheader(); writer.writerows(results)
    return 0

if __name__=='__main__':
    sys.exit(main())
