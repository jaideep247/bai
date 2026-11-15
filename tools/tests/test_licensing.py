"""Tests of the licensing tools: the module catalogue of the framework (valid, generated outputs up to date), the
payload rules, the decision twin of ZCL_CA_OPS_LIC_POLICY and - when the openssl command line is available - issuing
and verifying a licence with a throwaway key generated in a temporary directory (never a key of the repository).

Modification log:
2026-11-15 | Initial version (licensing).
"""
import contextlib
import datetime
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'licensing'))
from abaptools import licensing  # noqa: E402
import issue_license  # noqa: E402
import verify_license  # noqa: E402

FRAMEWORK = os.path.join(ROOT, 'ops-framework')
MODULES = os.path.join(FRAMEWORK, 'config', 'licensing', 'modules.json')
TODAY = datetime.date(2026, 11, 15)


def payload(**changes):
    body = {'license_id': 'ZT-LIC-0001', 'customer': 'ZT customer', 'installations': ['0020123456'],
            'systems': ['PS4/100', 'QA1'], 'version_from': '1.0', 'version_to': '1',
            'modules': ['JOBS:20261101:20271031', 'FLOW:20251101:20261130', 'BREAKS:20251101:20261031'],
            'grace_days': 30, 'issued_at': '20261101120000'}
    body.update(changes)
    return licensing.normalise(body)


class CatalogueTest(unittest.TestCase):

    def setUp(self):
        # the framework's profile, loaded by file (the name licensing is also a folder of tools/)
        spec = importlib.util.spec_from_file_location('zca_ops_licensing_profile',
                                                      os.path.join(FRAMEWORK, 'tools', 'licensing.py'))
        self.wrapper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.wrapper)
        self.spec = licensing.load(MODULES)

    def test_product_catalogue_valid_and_generated(self):
        self.assertEqual(licensing.check(FRAMEWORK, self.wrapper.PROFILE), [])

    def test_core_only_always_included(self):
        self.assertEqual([m['code'] for m in self.spec['modules'] if m.get('always')], ['CORE'])

    def test_every_catalogue_package_has_a_module(self):
        rows = licensing.catalogue_rows(licensing.profile_packages(self.wrapper.PROFILE))
        kinds = {(kind, name): module for kind, name, module, _ in rows}
        self.assertEqual(kinds[('PKG', 'S4CORE')], 'CORE')
        self.assertEqual(kinds[('PKG', 'FICA')], 'CATALOGUE_FICA')
        self.assertEqual(kinds[('PKG', 'FSCD')], 'CATALOGUE_FSCD')
        self.assertEqual(kinds[('PRC', 'FSCD_FSRI')], 'CATALOGUE_FSRI')

    def test_unknown_module_of_a_package_refused(self):
        spec = json.loads(json.dumps(self.spec))
        spec['modules'] = [m for m in spec['modules'] if m['code'] != 'CATALOGUE_FSRI']
        problems = licensing.validate(spec, FRAMEWORK, self.wrapper.PROFILE)
        self.assertTrue(any('FSCD_FSRI' in p for p in problems), problems)

    def test_check_class_in_no_module_refused(self):
        spec = json.loads(json.dumps(self.spec))
        for mod in spec['modules']:
            mod['check_classes'] = [c for c in mod['check_classes'] if c != 'ZCL_CA_OPS_CHK_BREAK']
        problems = licensing.validate(spec, FRAMEWORK, self.wrapper.PROFILE)
        self.assertIn('check class ZCL_CA_OPS_CHK_BREAK: in no module (add it to check_classes of its module)',
                      problems)

    def test_gate_without_its_constant_refused(self):
        spec = json.loads(json.dumps(self.spec))
        flow = next(m for m in spec['modules'] if m['code'] == 'FLOW')
        flow['gates'] = ['src/zca_ops_retention.prog.abap']
        problems = licensing.validate(spec, FRAMEWORK, self.wrapper.PROFILE)
        self.assertTrue(any('does not name gc_module-flow' in p for p in problems), problems)

    def test_configuration_without_validation_refused(self):
        spec = json.loads(json.dumps(self.spec))
        flow = next(m for m in spec['modules'] if m['code'] == 'FLOW')
        flow['config'] = ['FlowTileStage']
        problems = licensing.validate(spec, FRAMEWORK, self.wrapper.PROFILE)
        self.assertTrue(any('FlowTileStage has no licence validation' in p for p in problems), problems)

    def test_generated_class_holds_every_row(self):
        rows = licensing.map_rows(self.spec, self.wrapper.PROFILE)
        with open(os.path.join(FRAMEWORK, 'src', 'zcl_ca_ops_lic_map.clas.abap'), encoding='utf-8') as handle:
            source = handle.read()
        self.assertEqual(source.count('BEGIN OF gc_r'), len(rows))
        self.assertIn("VALUE 'ZCL_CA_OPS_CHK_JOB_FAIL'", source)


class PayloadTest(unittest.TestCase):

    def setUp(self):
        self.spec = licensing.load(MODULES)

    def test_friendly_form_normalised(self):
        body = payload()['LICENSE']
        self.assertEqual(body['SYSTEMS'], [{'SID': 'PS4', 'CLIENT': '100'}, {'SID': 'QA1', 'CLIENT': ''}])
        self.assertEqual(body['MODULES'][0], {'CODE': 'JOBS', 'VALID_FROM': '20261101', 'VALID_TO': '20271031'})
        self.assertEqual(body['FORMAT'], 1)
        self.assertEqual(licensing.validate_payload(payload(), self.spec), [])

    def test_canonical_json_is_the_abap_shape(self):
        text = licensing.canonical_json(payload()).decode('utf-8')
        self.assertTrue(text.startswith('{"LICENSE":{"FORMAT":1,"LICENSE_ID":"ZT-LIC-0001"'))
        self.assertNotIn(' ', text.replace('ZT customer', ''))

    def test_rules(self):
        problems = licensing.validate_payload(payload(installations=['12'], systems=['TOOLONG'],
                                                      modules=['NOPE:20261101:20251101'], grace_days=400,
                                                      version_from='2', version_to='1'), self.spec)
        text = '\n'.join(problems)
        for part in ("installation '12'", 'SID of three characters', 'module NOPE: not a module',
                     'module NOPE: VALID_FROM after VALID_TO', 'GRACE_DAYS', 'VERSION_FROM after VERSION_TO'):
            self.assertIn(part, text)

    def test_missing_requirement_reported(self):
        missing = licensing.missing_requirements(payload(modules=['CATALOGUE_FSCD:20261101:20271031']), self.spec)
        self.assertIn('CATALOGUE_FSCD requires ONBOARD', missing)
        self.assertIn('CATALOGUE_FSCD requires CATALOGUE_FICA', missing)


class DecisionTwinTest(unittest.TestCase):
    CODES = ('JOBS', 'FLOW', 'BREAKS', 'LINKS')

    def evaluate(self, data=None, **kwargs):
        args = dict(installation='0020123456', sid='PS4', client='100', codes=self.CODES)
        args.update(kwargs)
        return licensing.evaluate(payload() if data is None else data, TODAY, **args)

    def test_states(self):
        modules = self.evaluate()['modules']
        self.assertEqual(modules['CORE']['state'], 'INCLUDED')
        self.assertEqual(modules['JOBS']['state'], 'LICENSED')
        self.assertEqual(modules['FLOW']['state'], 'EXPIRING')
        self.assertEqual(modules['FLOW']['days_left'], 15)
        self.assertEqual(modules['BREAKS']['state'], 'GRACE')
        self.assertEqual(modules['LINKS']['state'], 'UNLICENSED')

    def test_enforcement(self):
        refused = self.evaluate(payload(grace_days=0), enforce='X')['modules']
        self.assertEqual(refused['BREAKS']['state'], 'EXPIRED')
        self.assertFalse(refused['BREAKS']['runs'])
        self.assertFalse(refused['LINKS']['runs'])
        self.assertTrue(refused['CORE']['runs'])
        self.assertTrue(self.evaluate(payload(grace_days=0), enforce='W')['modules']['BREAKS']['runs'])

    def test_licence_states(self):
        self.assertEqual(self.evaluate(installation='0020999999')['state'], 'BINDING')
        self.assertEqual(self.evaluate(client='200')['state'], 'BINDING')
        self.assertEqual(self.evaluate(sid='QA1', client='300')['state'], 'VALID')
        self.assertEqual(self.evaluate(version='2.0.0')['state'], 'VERSION')
        self.assertEqual(self.evaluate(signature_ok=False)['state'], 'SIGNATURE')
        missing = licensing.evaluate(None, TODAY, codes=self.CODES)
        self.assertEqual(missing['state'], 'MISSING')
        self.assertTrue(missing['modules']['JOBS']['runs'])
        self.assertFalse(licensing.evaluate(None, TODAY, codes=self.CODES, enforce='X')['modules']['JOBS']['runs'])

    def test_versions(self):
        self.assertTrue(licensing.version_in_range('1.9.3', '1', '1'))
        self.assertFalse(licensing.version_in_range('1.10.0', '1.2', '1.9'))
        self.assertTrue(licensing.version_in_range('1.0.0', '1.0', '1'))


@unittest.skipUnless(shutil.which('openssl'), 'openssl command line not available')
class SignedLicenceTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.mkdtemp(prefix='zca_lic_test_')
        for name, subject in (('vendor', '/CN=ZCA_OPS LICENSING'), ('other', '/CN=ZT SELF SIGNED')):
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-sha256', '-days', '2',
                            '-subj', subject, '-keyout', os.path.join(cls.work, f'{name}.key'),
                            '-out', os.path.join(cls.work, f'{name}.crt')], check=True, capture_output=True)
        with open(os.path.join(cls.work, 'payload.json'), 'w', encoding='utf-8') as handle:
            json.dump(payload(), handle)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work, ignore_errors=True)

    def path(self, name):
        return os.path.join(self.work, name)

    def issue(self, out, key='vendor', extra=()):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return issue_license.main(['--key', self.path(f'{key}.key'), '--cert', self.path(f'{key}.crt'),
                                       '--payload', self.path('payload.json'), '--out', self.path(out)] + list(extra))

    def verify(self, licence, cert='vendor', extra=()):
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = verify_license.main(['--cert', self.path(f'{cert}.crt'), '--licence', self.path(licence),
                                        '--today', '20261115'] + list(extra))
        return code, json.loads(buffer.getvalue())

    def test_issue_and_verify(self):
        self.assertEqual(self.issue('ok.pem', extra=['--force']), 0)
        with open(self.path('ok.pem'), encoding='ascii') as handle:
            text = handle.read()
        self.assertIn('-----BEGIN CMS-----', text)
        code, out = self.verify('ok.pem', extra=['--installation', '0020123456', '--sid', 'PS4', '--client', '100'])
        self.assertEqual(code, 0, out)
        self.assertEqual(out['signature'], 'ok')
        self.assertEqual(out['signer_subject'], 'CN=ZCA_OPS LICENSING')
        self.assertEqual(len(out['signer_sha256']), 64)
        self.assertEqual(out['payload'], payload())
        self.assertEqual(out['status']['modules']['FLOW']['state'], 'EXPIRING')

    def test_other_system_is_binding(self):
        self.assertEqual(self.issue('bind.pem', extra=['--force']), 0)
        code, out = self.verify('bind.pem', extra=['--installation', '0020999999', '--sid', 'PS4'])
        self.assertEqual(code, 1)
        self.assertEqual(out['status']['state'], 'BINDING')

    def test_tampered_or_foreign_licence_refused(self):
        self.assertEqual(self.issue('signed.pem', extra=['--force']), 0)
        with open(self.path('signed.pem'), encoding='ascii') as handle:
            lines = handle.read().splitlines()
        middle = len(lines) // 2
        lines[middle] = lines[middle][:-4] + ('AAAA' if not lines[middle].endswith('AAAA') else 'BBBB')
        with open(self.path('tampered.pem'), 'w', encoding='ascii') as handle:
            handle.write('\n'.join(lines) + '\n')
        self.assertEqual(self.verify('tampered.pem')[1]['signature'], 'invalid')
        # signed by another key: not the vendor's certificate
        self.assertEqual(self.issue('foreign.pem', key='other', extra=['--force']), 0)
        self.assertEqual(self.verify('foreign.pem')[1]['signature'], 'invalid')

    def test_requirements_and_key_location(self):
        # the payload grants modules whose requirements it lacks? JOBS / FLOW / BREAKS need nothing: issued
        self.assertEqual(self.issue('plain.pem'), 0)
        with open(self.path('fscd.json'), 'w', encoding='utf-8') as handle:
            json.dump(payload(modules=['CATALOGUE_FSCD:20261101:20271031']), handle)
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            refused = issue_license.main(['--key', self.path('vendor.key'), '--cert', self.path('vendor.crt'),
                                          '--payload', self.path('fscd.json'), '--out', self.path('fscd.pem')])
            in_repo = issue_license.main(['--key', MODULES, '--cert', self.path('vendor.crt'),
                                          '--payload', self.path('payload.json'), '--out', self.path('x.pem')])
        self.assertEqual(refused, 1)
        self.assertEqual(in_repo, 1)


if __name__ == '__main__':
    unittest.main()
