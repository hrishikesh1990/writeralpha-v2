#!/usr/bin/env python3
"""Mechanical checks for WriterAlpha drafts. Usage: check_draft.py file.md [--json]"""
import sys, re, json, os
BASE = os.path.dirname(os.path.abspath(__file__))
try:
    known = set(json.load(open(os.path.join(BASE, 'data/known_urls.json'))))
except Exception:
    known = set()
BANNED = [r"\bwe tested\b", r"\bin our (?:experience|testing|tests)\b", r"\bour team\b", r"\bscientifically proven\b", r"\bguaranteed?\b",
          r"\bwill (?:heal|cure|attract|protect you|remove negative)", r"\bcures?\b", r"\bproven to\b", r"\bKey Takeaways\b", r"Table of Contents",
          r"\bIn conclusion\b", r"\bIn this (?:article|guide|post),? we", r"\bDive (?:in|deep)\b", r"\bunlock\b", r"\bharness the power\b", r"\bjourney\b", r"\bdelve\b", r"\btapestry\b", r"\bIn today's\b"]
def check(path):
    txt = open(path, encoding='utf-8').read()
    res = []
    def r(ok, name, detail=''):
        res.append((ok, name, detail))
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", txt, re.S)
    r(bool(m), 'front matter present')
    if not m:
        return res
    fm, body = m.groups()
    def fmv(k):
        mm = re.search(rf"^{k}:\s*(.*)$", fm, re.M); return mm.group(1).strip() if mm else ''
    for k in ['url', 'title', 'meta_title', 'meta_description', 'intent_id', 'frame', 'evidence_basis']:
        r(bool(fmv(k)), f'front matter has {k}')
    md = fmv('meta_description'); r(130 <= len(md) <= 170, 'meta_description 130-170 chars', str(len(md)))
    r(len(fmv('meta_title')) <= 65, 'meta_title <= 65 chars', str(len(fmv('meta_title'))))
    h1 = re.findall(r"^# (.+)$", body, re.M); r(len(h1) == 1, 'exactly one H1', str(len(h1)))
    h2 = re.findall(r"^## (.+)$", body, re.M); r(len(h2) >= 3, 'at least 3 H2 sections', str(len(h2)))
    # opening answer
    after_h1 = body.split('\n# ', 1)[-1] if body.strip().startswith('# ') else body
    paras = [p.strip() for p in re.split(r"\n\s*\n", after_h1.split('\n', 1)[1] if '\n' in after_h1 else '') if p.strip() and not p.strip().startswith('#')]
    first = paras[0] if paras else ''
    r(0 < len(first.split()) <= 75, 'opening paragraph <= 75 words', str(len(first.split())))
    words = len(re.findall(r"\w+", body)); r(words >= 500, 'body >= 500 words', str(words))
    for pat in BANNED:
        hits = re.findall(pat, body, re.I)
        r(not hits, f'no banned phrase {pat}', '; '.join(hits[:3]))
    links = re.findall(r"\]\((/[^)\s]+)\)", body)
    r(len(links) >= 2, 'at least 2 internal links', str(len(links)))
    ext = re.findall(r"\]\((https?://[^)]+)\)", body)
    if known:
        bad = [l for l in links if l.split('#')[0] not in known]
        r(not bad, 'all internal links resolve to known URLs', ', '.join(bad[:5]))
    r(not re.search(r"^---\s*$", body, re.M), 'no horizontal rules in body')
    r(not re.search(r"[\U0001F300-\U0001FAFF☀-➿]", body), 'no emoji')
    # section subject test: each H2 section's first sentence should not start with a pronoun
    secs = re.split(r"^## .+$", body, flags=re.M)[1:]
    pron = [s.strip().split('\n')[0][:40] for s in secs if re.match(r"^\s*(It|They|This|These|That|Those)\b", s.strip())]
    r(not pron, 'no H2 section opens with a bare pronoun', ' | '.join(pron[:3]))
    faqs = re.findall(r"^###? .*\?\s*$", body, re.M)
    r(len(faqs) <= 6, 'not a FAQ dump (<=6 question headings)', str(len(faqs)))
    return res
if __name__ == '__main__':
    files = [a for a in sys.argv[1:] if not a.startswith('--')]
    out = {}
    exit_code = 0
    for f in files:
        res = check(f); out[f] = res
        fails = [x for x in res if not x[0]]
        if fails: exit_code = 1
        if '--json' not in sys.argv:
            print(f"{'PASS' if not fails else 'FAIL'} {f}")
            for ok, name, d in fails: print(f"   FAIL {name}: {d}")
    if '--json' in sys.argv: print(json.dumps({f: [(n, d) for ok, n, d in v if not ok] for f, v in out.items()}, indent=1))
    sys.exit(exit_code)
