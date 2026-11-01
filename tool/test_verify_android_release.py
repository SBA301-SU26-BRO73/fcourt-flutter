"""Regression coverage for hosted apksigner output and signer mismatches."""
import hashlib
import os
from pathlib import Path
import ssl
import tempfile
import unittest
from unittest.mock import patch

from verify_android_release import verify


class VerifyAndroidReleaseTest(unittest.TestCase):
    certificate = b'disposable certificate fixture'
    fingerprint = hashlib.sha256(certificate).hexdigest()

    def verify_report(self, report, *, jar='jar verified.', bundle_certificate=None):
        if bundle_certificate is None:
            bundle_certificate = self.certificate
        pem = ssl.DER_cert_to_PEM_cert(bundle_certificate)
        with tempfile.TemporaryDirectory() as directory:
            sdk = Path(directory)
            signer = sdk / 'build-tools/36.0.0/apksigner'
            signer.parent.mkdir(parents=True)
            signer.touch()
            with (
                patch.dict(os.environ, {'ANDROID_STORE_PASSWORD': 'fixture'}),
                patch('verify_android_release.android_sdk', return_value=sdk),
                patch('verify_android_release.checked', side_effect=[self.certificate, report, jar, pem]) as checked,
            ):
                verify(sdk, sdk / 'fixture.jks', 'fixture', 'ANDROID_STORE_PASSWORD')
                return checked.call_args_list

    def test_numbered_and_scheme_specific_signers(self):
        for label in ['Signer #1', 'V2 Signer', 'V3 Signer', 'V3.1 Signer']:
            with self.subTest(label=label):
                calls = self.verify_report(f'{label} certificate SHA-256 digest: {self.fingerprint}\n')
                self.assertEqual(len(calls), 4)
                self.assertIn('verify', calls[1].args[0])
                self.assertIn('-verify', calls[2].args[0])

    def test_colon_separated_uppercase_fingerprint(self):
        digest = ':'.join(self.fingerprint[i:i + 2] for i in range(0, 64, 2)).upper()
        self.verify_report(f'V2 Signer certificate SHA-256 digest: {digest}\n')

    def test_repeated_schemes_with_same_certificate(self):
        self.verify_report('\n'.join(f'{label} certificate SHA-256 digest: {self.fingerprint}' for label in ['V2 Signer', 'V3 Signer']))

    def test_wrong_or_missing_apk_certificate_is_rejected(self):
        for report in [
            '',
            'V2 Signer certificate SHA-256 digest: ' + '0' * 64,
            'V2 Signer public key SHA-256 digest: ' + self.fingerprint,
            'Source Stamp Signer certificate SHA-256 digest: ' + self.fingerprint,
            'V2 Signer certificate SHA-256 digest: abc123',
        ]:
            with self.subTest(report=report), self.assertRaisesRegex(RuntimeError, 'APK signer mismatch'):
                self.verify_report(report)

    def test_additional_apk_signer_is_rejected(self):
        report = f'Signer #1 certificate SHA-256 digest: {self.fingerprint}\nSigner #2 certificate SHA-256 digest: ' + '0' * 64
        with self.assertRaisesRegex(RuntimeError, 'APK signer mismatch'):
            self.verify_report(report)

    def test_unsigned_bundle_is_rejected(self):
        report = f'V2 Signer certificate SHA-256 digest: {self.fingerprint}'
        for jar in ['jar is unsigned.', 'jar verified.\nThis jar contains unsigned entries.']:
            with self.subTest(jar=jar), self.assertRaisesRegex(RuntimeError, 'AAB is not fully signed'):
                self.verify_report(report, jar=jar)

    def test_wrong_bundle_certificate_is_rejected(self):
        report = f'V2 Signer certificate SHA-256 digest: {self.fingerprint}'
        with self.assertRaisesRegex(RuntimeError, 'AAB signer does not match'):
            self.verify_report(report, bundle_certificate=b'another certificate')


if __name__ == '__main__':
    unittest.main()
