import base64
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import prepare_android_release


class PrepareAndroidReleaseTest(unittest.TestCase):
    def test_release_environment_file_selects_production(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / 'github.env'
            environment = {
                'ANDROID_KEYSTORE_BASE64': base64.b64encode(b'keystore').decode(),
                'ANDROID_KEY_ALIAS': 'upload',
                'ANDROID_KEY_PASSWORD': 'key-secret',
                'ANDROID_STORE_PASSWORD': 'store-secret',
                'PRODUCTION_API_BASE_URL': 'https://api.fcourt.vn',
                'RUNNER_TEMP': directory,
                'GITHUB_ENV': str(env_file),
            }
            with patch.dict(os.environ, environment, clear=True):
                prepare_android_release.main()
            written = json.loads((Path(directory) / 'fcourt-release-signing/production.json').read_text())
        self.assertEqual({'APP_ENV': 'prod', 'API_BASE_URL': 'https://api.fcourt.vn'}, written)


if __name__ == '__main__':
    unittest.main()
