#!/usr/bin/env python3
"""Builds assets/features.json and FEATURES_STATUS.md.

Sources: FEATURES.md (number, name, description, section) and tools/feature_meta.txt
(one line per built feature: number|status|rank or empty|note).
Features with no meta line are listed as "todo" and stay hidden in the app.
"""
import json, re, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
text = (root / 'FEATURES.md').read_text()
features, section, secnum = [], '', 0
for line in text.splitlines():
    m = re.match(r'^## (\d+)\. (.+?)(?: \((\d+) to (\d+)\))?$', line)
    if m and m.group(1) != '702':
        section = m.group(2)
        secnum = int(m.group(1))
        continue
    if line.startswith('## 702'):
        section = 'The one rule'
        secnum = 1
        continue
    m = re.match(r'^- \*\*(\d+)\. (.+?)\*\*\s*(.*)$', line)
    if m:
        name = m.group(2).rstrip('.')
        features.append({'n': int(m.group(1)), 'name': name, 'desc': m.group(3).strip(), 'sec': section, 'secnum': secnum})
assert [f['n'] for f in features] == list(range(1, 703)), len(features)

meta = {}
mp = root / 'tools' / 'feature_meta.txt'
if mp.exists():
    for line in mp.read_text().splitlines():
        if not line.strip() or line.startswith('#'):
            continue
        n, status, rank, note = (line.split('|') + ['', '', ''])[:4]
        meta[int(n)] = (status.strip(), rank.strip(), note.strip())

V1 = {1, 2, 5, 11, 26, 27, 51, 52, 76, 79, 126, 151, 226, 188, 470, 213, 248, 327, 67}
out = []
for f in features:
    status, rank, note = meta.get(f['n'], ('todo', '', ''))
    # Feature 492: later sections appear at higher ranks unless the meta line says otherwise.
    rank = int(rank) if rank != '' else min(8, (f['secnum'] - 1) // 3)
    f = {k: v for k, v in f.items() if k != 'secnum'}
    out.append({**f, 'status': status, 'rank': 0 if f['n'] in V1 else rank, 'v1': f['n'] in V1, 'on': True})
(root / 'assets' / 'features.json').write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')))

counts = {}
for f in out:
    counts[f['status']] = counts.get(f['status'], 0) + 1
head = (root / 'tools' / 'status_head.md')
lines = [head.read_text().rstrip() if head.exists() else '# Feature status', '',
         'Totals: ' + ', '.join(f'{k} {v}' for k, v in sorted(counts.items())) + f' (of {len(out)}).', '',
         'Status words: **done** = built and covered by tests or trivially simple; **partial** = a '
         'working smaller version, the note says what is missing; **needs-backend** = screen and local '
         'logic built against a fake, see BACKEND.md; **blocked** = Android does not allow it, closest '
         'allowed version built; **todo** = not built yet. "Built, untested on device" means the code '
         'exists and compiles but has never run on a phone: it is on the phone test checklist.', '', '| # | Feature | Status | Note |', '| --- | --- | --- | --- |']
for f in out:
    note = meta.get(f['n'], ('', '', ''))[2]
    lines.append(f"| {f['n']} | {f['name']} | {f['status']} | {note} |")
(root / 'FEATURES_STATUS.md').write_text('\n'.join(lines) + '\n')
print(counts)
