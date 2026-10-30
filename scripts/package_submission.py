"""Package deliverables, excluding installed tools, caches and report QA images."""
from pathlib import Path
import hashlib
import json
import zipfile

root=Path(__file__).resolve().parents[1]
summary=json.loads((root/'results/verification_summary.json').read_text())
assert summary['mode']=='full' and summary['passed'], 'Full verification is required.'
for filename,digest in summary['source_sha256'].items():
    assert hashlib.sha256((root/filename).read_bytes()).hexdigest()==digest, f'Stale verification: {filename}'
files=[root/'README.md',root/'.gitignore',root/'CAO-PROJECT-2026.docx']
for folder in ('rtl','tb','vectors','scripts','results','docs'):
    for path in sorted((root/folder).rglob('*')):
        relative=path.relative_to(root)
        if path.is_file() and path.name!='submission_manifest.json' and not any(p in ('qa','__pycache__') for p in relative.parts) and not path.name.startswith('~$'):
            files.append(path)
manifest={str(path.relative_to(root)).replace('\\','/'):hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
(root/'results/submission_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
files.append(root/'results/submission_manifest.json')
archive=root/'Project_2_Submission.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for path in files: z.write(path,str(path.relative_to(root)))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
print(f'Packaged {len(files)} files into {archive.name} ({archive.stat().st_size:,} bytes).')
