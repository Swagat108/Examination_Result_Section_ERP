"""Extract the TY E&TC 2026-27 Sem-V roll-call PDF into db/seed/data/etc_ty_sem5_2026_27.csv.

Usage:  python -I db/tools/extract_roster.py "<roll-call.pdf>" db/seed/data/etc_ty_sem5_2026_27.csv

Canonical rows come from pages 2-9 (TY V .. TY VIII). Pages 10-16 repeat the same students
grouped by elective and are used only to cross-check names and fill rows the table parser drops.
"""
import csv, re, sys, collections
import pdfplumber

PDF, OUT = sys.argv[1], sys.argv[2]
pdf = pdfplumber.open(PDF)
clean = lambda s: re.sub(r'\s+', ' ', (s or '')).strip()
ROLL = re.compile(r'\d{5}')

def table_rows(pages):
    for pn in pages:
        for t in pdf.pages[pn - 1].extract_tables():
            for r in t:
                r = [clean(c) for c in r]
                if len(r) >= 8 and r[0].isdigit() and ROLL.fullmatch(r[1]):
                    yield pn, r

def parse(r):
    if len(r) == 8:                       # TY V layout has no honours column
        _, roll, div, mdm, enrol, name, pe1, batch = r; honors = ''
    else:
        _, roll, div, mdm, enrol, name, pe1, honors, batch = r[:9]
    return dict(roll_no=roll, division=div, mdm=mdm, enrollment_no=enrol, full_name=name,
                pe1=pe1, honors=honors, batch=batch)

students = {}
for _, r in table_rows(range(2, 10)):
    s = parse(r); students[s['roll_no']] = s

# Cross-check lists (pages 10-16): authoritative for names that overlap in the main table
alt = {}
for _, r in table_rows(range(10, 17)):
    s = parse(r); alt[s['roll_no']] = s
for roll, a in alt.items():
    m = students.get(roll)
    if m and m['enrollment_no'] == a['enrollment_no'] and m['full_name'] != a['full_name']:
        print(f"name fix {roll}: {m['full_name']!r} -> {a['full_name']!r}")
        m['full_name'] = a['full_name']
    elif m and m['enrollment_no'] != a['enrollment_no']:
        print(f"WARNING roll {roll} differs: {m['enrollment_no']} vs {a['enrollment_no']}")

# Rows the PDF table parser drops (rows highlighted / red text); read from page images + duplicate lists
RECOVERED = [
    dict(roll_no='32124', division='TY V',  mdm='', enrollment_no='F24ET306', full_name='KAMBLE ATHARVA ANANT',
         pe1='Cloud Computing (CC)', honors='', batch='L5'),
    dict(roll_no='32231', division='TY VI', mdm='', enrollment_no='F24ET128', full_name='CHOUGULE SWAGAT SUNIL',
         pe1='Cloud Computing (CC)', honors='', batch='L6'),
    dict(roll_no='32327', division='TY VII', mdm='', enrollment_no='F24ET117', full_name='DESHPANDE VAIBHAVI SANJAY',
         pe1='Digital Image and Video Processing (DIVP)', honors='', batch='L7'),
    dict(roll_no='32467', division='TY VIII', mdm='', enrollment_no='S25ET038', full_name='SURWASE SHRADHHA GOVIND',
         pe1='CMOS Analog Circuit Design (CACD)', honors='', batch='M8'),
]
for s in RECOVERED:
    students.setdefault(s['roll_no'], s)

# Normalise elective labels to their code (some cells are garbled by overlapping text in the PDF)
PE1 = {'CC': 'Cloud Computing (CC)', 'DIVP': 'Digital Image and Video Processing (DIVP)',
       'MI': 'Microcontrollers and IoT (MI)', 'CACD': 'CMOS Analog Circuit Design (CACD)'}
HON = {'VLSI-DT': 'Honors: VLSI Design Technology (VLSI-DT)', 'IoT': 'Internet of Things (IoT)',
       'BCT': 'Block Chain Technology (BCT)'}
for s in students.values():
    s['pe1'] = PE1[re.search(r'\(([^)]+)\)\s*$', s['pe1']).group(1)]
    if s['honors']:
        s['honors'] = HON[re.search(r'\(([^)]+)\)\s*$', s['honors']).group(1)]

rows = sorted(students.values(), key=lambda s: s['roll_no'])
with open(OUT, 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

print('rows', len(rows))
for k in ('division', 'pe1', 'honors', 'mdm'):
    print(k, dict(collections.Counter(s[k] for s in rows)))
