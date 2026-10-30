"""Run from any directory. Python 3 stdlib only; Icarus must be on PATH or local."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quick', action='store_true', help='Skip exhaustive 8-bit ALU run')
    args = parser.parse_args()
    os.chdir(ROOT)
    cached = Path(os.environ.get('LOCALAPPDATA', str(ROOT/'.tools')))/'cao-hdl-tools/iverilog/bin'
    local = Path(os.environ['IVERILOG_BIN']) if 'IVERILOG_BIN' in os.environ else (cached if cached.is_dir() else ROOT/'.tools/iverilog/app/bin')
    compiler = shutil.which('iverilog') or str(local/'iverilog.exe')
    runtime = shutil.which('vvp') or str(local/'vvp.exe')
    if not Path(compiler).is_file() or not Path(runtime).is_file():
        raise SystemExit('Install Icarus Verilog and put iverilog/vvp on PATH. See README.md.')
    # Some Windows Icarus builds do not quote internal executable paths.
    # The workspace itself may contain spaces; use the filesystem's short alias.
    backend = []
    if os.name == 'nt':
        lib = Path(compiler).resolve().parents[1]/'lib/ivl'
        if lib.is_dir():
            buffer = ctypes.create_unicode_buffer(32768)
            size = ctypes.windll.kernel32.GetShortPathNameW(str(lib), buffer, len(buffer))
            if size and ' ' not in buffer.value:
                backend = ['-B', buffer.value]
    subprocess.run([sys.executable, 'scripts/generate_vectors.py'], check=True)
    (ROOT/'.build').mkdir(exist_ok=True)
    (ROOT/'results').mkdir(exist_ok=True)
    jobs = [('tb_units', None), ('tb_alu', 4)]
    if not args.quick:
        jobs.append(('tb_alu', 8))
    jobs += [('tb_alu', 16), ('tb_decoder', None), ('tb_top', None)]
    report = {'mode': 'quick' if args.quick else 'full', 'platform': platform.platform(),
              'compiler': compiler, 'tests': [], 'source_sha256': {}}
    version = subprocess.run([compiler, *backend, '-V'], capture_output=True, text=True)
    report['tool_version'] = version.stdout.splitlines()[0]
    sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'rtl').glob('*.v'))
    for path in sorted(list((ROOT/'rtl').glob('*'))+list((ROOT/'tb').glob('*.v'))):
        report['source_sha256'][str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    all_passed = True
    for top, width in jobs:
        name = top + (f'_{width}' if width else '')
        exe = str(ROOT/'.build'/f'{name}.vvp')
        command = [compiler, *backend, '-g2012', '-Wall', '-Irtl', '-Ivectors', '-s', top, '-o', exe]
        if width:
            command += [f'-P{top}.WIDTH={width}']
        command += sources+[f'tb/{top}.v']
        start = time.perf_counter()
        compile_result = subprocess.run(command, capture_output=True, text=True)
        log = compile_result.stdout+compile_result.stderr
        passed = compile_result.returncode == 0
        simulation_seconds = None
        if passed:
            simulation_start = time.perf_counter()
            simulation = subprocess.run([runtime, exe], capture_output=True, text=True)
            simulation_seconds = time.perf_counter()-simulation_start
            log += simulation.stdout+simulation.stderr
            passed = simulation.returncode == 0 and '[PASS]' in simulation.stdout and '[FAIL]' not in log
        duration = time.perf_counter()-start
        (ROOT/'results'/f'{name}.log').write_text(log)
        report['tests'].append({'name': name, 'passed': passed, 'elapsed_seconds': round(duration, 4),
                                'simulation_seconds': round(simulation_seconds, 4) if simulation_seconds is not None else None,
                                'compile_command': command})
        all_passed &= passed
        print(f'{"PASS" if passed else "FAIL"}: {name} ({duration:.2f} s)', flush=True)
        if not passed:
            print(log)
    report['passed'] = all_passed
    (ROOT/'results'/'verification_summary.json').write_text(json.dumps(report, indent=2)+'\n')
    return 0 if all_passed else 1

if __name__ == '__main__':
    sys.exit(main())
