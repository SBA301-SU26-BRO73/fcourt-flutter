"""Cryptographically check APK/AAB and compare their signer to the supplied keystore."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import ssl
import subprocess


def android_sdk():
    candidates = [os.environ.get('ANDROID_HOME'), os.environ.get('ANDROID_SDK_ROOT'), str(Path.home() / 'Library/Android/sdk')]
    for candidate in candidates:
        if candidate and (Path(candidate) / 'build-tools').is_dir():
            return Path(candidate)
    raise RuntimeError('Android SDK build-tools are required')


def checked(command, *, binary=False):
    result = subprocess.run(command, capture_output=True, env={**os.environ, 'LC_ALL': 'C'}, check=False)
    if result.returncode:
        raise RuntimeError('Release artifact verification command failed: ' + Path(command[0]).name)
    return result.stdout if binary else result.stdout.decode('utf-8', errors='replace')


def verify(project, keystore, alias, password_env):
    if not os.environ.get(password_env):
        raise RuntimeError('Keystore password environment variable is required')
    cert = checked(['keytool', '-exportcert', '-keystore', str(keystore), '-alias', alias, '-storepass:env', password_env], binary=True)
    expected = hashlib.sha256(cert).hexdigest()
    apk = Path(project) / 'build/app/outputs/flutter-apk/app-release.apk'
    aab = Path(project) / 'build/app/outputs/bundle/release/app-release.aab'
    tools = sorted((android_sdk() / 'build-tools').glob('*/apksigner'), reverse=True)
    if not tools:
        raise RuntimeError('apksigner is required')
    report = checked([str(tools[0]), 'verify', '--verbose', '--print-certs', str(apk)])
    # Build-tools can label scheme-specific certificates as "V2 Signer:" or
    # "V3 Signer:" instead of the older numbered "Signer #1" format.
    digests = re.findall(r'^(?:Signer #\d+|V\d+(?:\.\d+)? Signer:?) certificate SHA-256 digest:[ \t]*([0-9a-fA-F: ]+)[ \t]*$', report, re.M)
    normalized = {re.sub(r'[^0-9a-f]', '', v.lower()) for v in digests}
    if normalized != {expected}:
        if password_env == 'FCOURT_SMOKE_PASSWORD':
            print(report, flush=True)  # Public metadata from a disposable fixture only.
        raise RuntimeError('APK signer mismatch: expected SHA-256 ' + expected + ', observed ' + ','.join(sorted(normalized)))
    jar = checked(['jarsigner', '-verify', str(aab)])
    if 'jar verified.' not in jar.lower() or 'unsigned entries' in jar.lower():
        raise RuntimeError('AAB is not fully signed')
    bundle_certs = checked(['keytool', '-printcert', '-jarfile', str(aab), '-rfc'])
    pem = re.search(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', bundle_certs, re.S)
    if not pem or hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem.group())).hexdigest() != expected:
        raise RuntimeError('AAB signer does not match the configured release keystore')
    print('APK and AAB signatures match the configured release keystore.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', default='.')
    parser.add_argument('--keystore', required=True)
    parser.add_argument('--alias', required=True)
    parser.add_argument('--password-env', default='ANDROID_STORE_PASSWORD')
    args = parser.parse_args()
    verify(args.project, args.keystore, args.alias, args.password_env)
