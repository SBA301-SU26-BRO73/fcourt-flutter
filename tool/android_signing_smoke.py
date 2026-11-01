"""Build signed fixtures in a disposable checkout; never publish fixtures or retain their key."""
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile

from prepare_android_release import properties
from verify_android_release import verify


def main():
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='fcourt-signing-smoke-') as temp:
        project = Path(temp) / 'project'
        shutil.copytree(source, project, ignore=shutil.ignore_patterns('.git', 'build', '.dart_tool', '.gradle', '.idea', '.env*', 'key.properties', '*.jks', '*.keystore', '__pycache__'))
        environment = {**os.environ, 'FCOURT_SIGNING_PROPERTIES_FILE': str(Path(temp) / 'signing.properties')}
        def run(command, expected_success=True):
            result = subprocess.run(command, cwd=project, env=environment, capture_output=True, text=True, timeout=1500)
            if expected_success and result.returncode:
                # No real secrets are present in this disposable fixture checkout.
                print(result.stdout[-6000:]); print(result.stderr[-3000:])
                raise RuntimeError('Android signing smoke failed: ' + command[0])
            return result
        run(['flutter', 'pub', 'get'])
        print('Checking release fails without signing configuration...', flush=True)
        args = ['--release', '--dart-define=API_BASE_URL=https://signing-smoke.invalid']
        missing = run(['flutter', 'build', 'apk', *args], expected_success=False)
        if missing.returncode == 0 or 'FCOURT release signing requires' not in missing.stdout + missing.stderr:
            print(missing.stdout[-6000:]); print(missing.stderr[-3000:])
            raise RuntimeError('Missing signing configuration did not fail through the required guard')
        password = secrets.token_urlsafe(32)
        environment['FCOURT_SMOKE_PASSWORD'] = password
        key = Path(temp) / 'fixture.jks'
        run(['keytool', '-genkeypair', '-keystore', str(key), '-storetype', 'JKS', '-alias', 'fcourt-smoke', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '2', '-dname', 'CN=Disposable FCOURT signing test', '-storepass:env', 'FCOURT_SMOKE_PASSWORD', '-keypass:env', 'FCOURT_SMOKE_PASSWORD'])
        Path(environment['FCOURT_SIGNING_PROPERTIES_FILE']).write_text(properties({'storeFile': key, 'storePassword': password, 'keyAlias': 'fcourt-smoke', 'keyPassword': password}), encoding='utf-8')
        print('Building disposable release APK and AAB...', flush=True)
        run(['flutter', 'build', 'apk', *args])
        run(['flutter', 'build', 'appbundle', *args])
        # Pass the temporary password by environment variable name, never command line value.
        previous = os.environ.get('FCOURT_SMOKE_PASSWORD')
        os.environ['FCOURT_SMOKE_PASSWORD'] = password
        try:
            verify(project, key, 'fcourt-smoke', 'FCOURT_SMOKE_PASSWORD')
        finally:
            if previous is None:
                os.environ.pop('FCOURT_SMOKE_PASSWORD', None)
            else:
                os.environ['FCOURT_SMOKE_PASSWORD'] = previous
        print('Signing smoke passed; disposable artifacts/key are deleted.', flush=True)


if __name__ == '__main__':
    main()
