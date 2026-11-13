"""Prepare isolated CI signing inputs. Never print secret material."""
import base64
import json
import os
from pathlib import Path
from urllib.parse import urlparse


def properties(values):
    def escape(v):
        return v.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace(' ', '\\ ')
    return ''.join(k + '=' + escape(str(v)) + '\n' for k, v in values.items())


def main():
    required = ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD', 'ANDROID_STORE_PASSWORD', 'PRODUCTION_API_BASE_URL']
    missing = [k for k in required if not os.environ.get(k)]
    if missing:
        raise SystemExit('Configure release inputs: ' + ', '.join(missing))
    if os.environ['ANDROID_KEY_ALIAS'].lower() == 'androiddebugkey':
        raise SystemExit('Production release must use its dedicated upload key')
    parsed = urlparse(os.environ['PRODUCTION_API_BASE_URL'])
    host = parsed.hostname or ''
    if parsed.scheme != 'https' or parsed.username or parsed.password or parsed.query or parsed.fragment or not host or host in ['localhost', '127.0.0.1', '::1', 'example.com'] or host.endswith(('.example', '.invalid', '.localhost')):
        raise SystemExit('PRODUCTION_API_BASE_URL must be the real HTTPS backend URL')
    directory = Path(os.environ['RUNNER_TEMP']) / 'fcourt-release-signing'
    directory.mkdir(mode=0o700)
    try:
        key = base64.b64decode(os.environ['ANDROID_KEYSTORE_BASE64'], validate=True)
    except ValueError:
        raise SystemExit('ANDROID_KEYSTORE_BASE64 is invalid') from None
    if not key or len(key) > 1024 * 1024:
        raise SystemExit('Release keystore size is invalid')
    keystore = directory / 'release.jks'
    keystore.write_bytes(key)
    config = directory / 'signing.properties'
    config.write_text(properties({'storeFile': keystore, 'storePassword': os.environ['ANDROID_STORE_PASSWORD'], 'keyAlias': os.environ['ANDROID_KEY_ALIAS'], 'keyPassword': os.environ['ANDROID_KEY_PASSWORD']}), encoding='utf-8')
    environment = directory / 'production.json'
    environment.write_text(json.dumps({'APP_ENV': 'prod', 'API_BASE_URL': os.environ['PRODUCTION_API_BASE_URL']}))
    for path in [keystore, config, environment]:
        path.chmod(0o600)
    with open(os.environ['GITHUB_ENV'], 'a') as target:
        target.write(f'FCOURT_SIGNING_PROPERTIES_FILE={config}\nFCOURT_KEYSTORE_FILE={keystore}\nFCOURT_PRODUCTION_ENV_FILE={environment}\n')


if __name__ == '__main__':
    main()
