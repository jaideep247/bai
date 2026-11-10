"""The suite never writes a table of the frameworks (ZCA_OPS_*, ZCA_PARAM_*, draft tables ZCA_D_*):
results go through the store, framework configuration through the framework apps (2026-11-10).
Static scan of the production ABAP of src/ (test includes excluded, comments ignored)."""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WRITE = re.compile(r'^\s*(UPDATE|INSERT|MODIFY|DELETE)\s+(FROM\s+)?(zca_\w+)', re.I | re.M)


def framework_writes(root):
    hits = []
    for folder, _, files in os.walk(os.path.join(root, 'src')):
        for name in sorted(files):
            if not name.endswith('.abap') or '.testclasses.' in name:
                continue
            with open(os.path.join(folder, name), encoding='utf-8') as fh:
                code = '\n'.join(l for l in fh.read().splitlines() if not l.lstrip().startswith(('*', '"')))
            hits += [f'{name}: {m.group(1)} {m.group(3)}' for m in WRITE.finditer(code)]
    return hits


class NoFrameworkWriteTest(unittest.TestCase):

    def test_suite_writes_no_framework_table(self):
        self.assertEqual(framework_writes(ROOT), [])

    def test_scan_finds_a_write(self):
        self.assertTrue(WRITE.search('    UPDATE zca_ops_alrule FROM TABLE @lt_rule.'))
        self.assertTrue(WRITE.search('    DELETE FROM zca_ops_finding WHERE run_id = @lv_id.'))
        self.assertIsNone(WRITE.search('    SELECT rule_id FROM zca_ops_alrule INTO TABLE @DATA(lt).'))


if __name__ == '__main__':
    unittest.main()
