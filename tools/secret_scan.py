#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════
# secret_scan.py — F7.4: «لا أسرار بالحزمة» (docs/11 §١٢ + docs/16 §١).
# يمسح كل ما قد يصل إلى APK/المستودع بحثاً عن أي سر خاص، ويفشل (exit 1)
# عند أول إصابة. يُشغَّل قبل كل بناء وقبل كل دفع.
#
#   python3 tools/secret_scan.py            # المستودع كاملاً
#   python3 tools/secret_scan.py app/lib    # نطاق أضيق
#
# ما هو «سر» عندنا (لا يجوز وجوده في العميل/المستودع):
#   - بذرة توقيع التراخيص SIGNING_SEED_B64 أو أي مفتاح Ed25519 خاص
#   - مفتاح المكتب OFFICE_KEY
#   - مفتاح service_role لـSupabase (JWT بدور service_role)
#   - رموز GitHub (ghp_/github_pat_) أو أي Bearer ثابت
#   - ملفات .env / مفاتيح PEM / keystore
# ما هو عامّ بالتصميم (مسموح — لا يُبلَّغ عنه):
#   - SUPABASE_URL ومفتاح anon (JWT بدور anon) — الحماية بـRLS
#   - المفتاح العام للتراخيص (licensePublicKey) — للتحقق فقط
# ═══════════════════════════════════════════════════════════════════════
import base64
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SKIP_DIRS = {
    '.git', 'node_modules', 'build', '.dart_tool', '.idea', '.gradle',
    '.pub-cache', 'ios', 'macos', 'windows', 'linux', 'web', '.local',
}
SKIP_EXT = {
    '.png', '.jpg', '.jpeg', '.webp', '.gif', '.ico', '.ttf', '.otf',
    '.pdf', '.zip', '.apk', '.aab', '.jar', '.so', '.docx', '.xlsx',
}
# الفاحص نفسه يحتوي الأنماط — لا يفحص نفسه
SELF = os.path.abspath(__file__)

PATTERNS = [
    ('GitHub token', re.compile(r'\b(ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b')),
    ('PEM private key', re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |)PRIVATE KEY-----')),
    ('OFFICE_KEY value', re.compile(r'OFFICE_KEY\s*[:=]\s*[\'"]?[A-Za-z0-9+/=_-]{24,}')),
    ('SIGNING_SEED value', re.compile(r'SIGNING_SEED_B64\s*[:=]\s*[\'"]?[A-Za-z0-9+/=]{40,}')),
    ('AWS key', re.compile(r'\bAKIA[0-9A-Z]{16}\b')),
    ('Slack/Stripe-like token', re.compile(r'\b(xox[baprs]-[A-Za-z0-9-]{10,}|sk_live_[A-Za-z0-9]{16,})\b')),
]
JWT_RE = re.compile(r'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}')
# JWT مجزّأ في Dart بسلاسل متجاورة: 'eyJ...' 'eyJ...' — نُلصقها قبل الفحص
DART_CONCAT_RE = re.compile(r"'([^'\n]*)'\s*\n?\s*'([^'\n]*)'")

FORBIDDEN_FILES = re.compile(r'(^|/)(\.env(\..+)?|.*\.jks|.*\.keystore|.*\.p12|.*\.pem|id_rsa|id_ed25519)$')


def jwt_role(token: str):
    try:
        payload = token.split('.')[1]
        payload += '=' * (-len(payload) % 4)
        data = json.loads(base64.urlsafe_b64decode(payload))
        return data.get('role')
    except Exception:
        return None


def join_dart_strings(text: str) -> str:
    prev = None
    while prev != text:
        prev = text
        text = DART_CONCAT_RE.sub(lambda m: "'" + m.group(1) + m.group(2) + "'", text)
    return text


def scan_file(path: str, findings: list):
    rel = os.path.relpath(path, ROOT)
    if FORBIDDEN_FILES.search(rel.replace(os.sep, '/')):
        findings.append((rel, 0, 'forbidden file type in repo'))
        return
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            text = f.read()
    except OSError:
        return
    for name, rx in PATTERNS:
        for m in rx.finditer(text):
            line = text.count('\n', 0, m.start()) + 1
            findings.append((rel, line, name))
    joined = join_dart_strings(text)
    for m in JWT_RE.finditer(joined):
        role = jwt_role(m.group(0))
        if role in (None, 'anon'):
            continue  # anon عامّ بالتصميم
        findings.append((rel, 0, f'JWT with role={role}'))


def main():
    targets = [os.path.join(ROOT, a) for a in sys.argv[1:]] or [ROOT]
    findings = []
    for t in targets:
        for dirpath, dirnames, filenames in os.walk(t):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for fn in filenames:
                p = os.path.join(dirpath, fn)
                if os.path.abspath(p) == SELF:
                    continue
                if os.path.splitext(fn)[1].lower() in SKIP_EXT:
                    continue
                scan_file(p, findings)
    if findings:
        print('✗ أسرار محتملة — امنع البناء/الدفع حتى تُزال:')
        for rel, line, what in findings:
            loc = f'{rel}:{line}' if line else rel
            print(f'  - {loc}  ← {what}')
        sys.exit(1)
    print('✓ لا أسرار بالحزمة/المستودع (anon والمفتاح العام مسموحان بالتصميم)')


if __name__ == '__main__':
    main()
