#!/usr/bin/env python3
"""Exercise the installer's actual pacman migration in an isolated directory."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
code = (root / 'install.sh').read_text().split("python3 - <<'PY'\n", 1)[1].split('\nPY', 1)[0]
server = 'Server = https://github.com/Geanziin/nvgd-repo/releases/download/packages'
fixtures = [
    '[options]\nArchitecture = auto\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n',
    '[options]\nColor\n[nvgd]\nServer = https://geanziin.github.io/nvgd-repo/$arch\n[core]\nInclude = /etc/pacman.d/mirrorlist\n',
    '[options]\nColor\n[nouveau-lab]\nServer = old1\n[nvgd-dkms]\nServer = old2\n[nvgd]\nServer = old3\n[extra]\nInclude = mirror\n',
]
for original in fixtures:
    with tempfile.TemporaryDirectory(prefix='nvgd-repository-test-') as directory:
        path = Path(directory) / 'pacman.conf'
        path.write_text(original)
        isolated = code.replace("path = pathlib.Path('/etc/pacman.conf')",
                                f'path = pathlib.Path({str(path)!r})')
        assert isolated != code
        subprocess.run(['python3', '-c', isolated], check=True, capture_output=True)
        updated = path.read_text()
        assert updated.count('[nvgd]') == 1 and server in updated
        assert '[nouveau-lab]' not in updated and '[nvgd-dkms]' not in updated
        assert updated.index('[options]') < updated.index('[nvgd]')
        for section in ('[core]', '[extra]'):
            if section in original:
                assert updated.index('[nvgd]') < updated.index(section)
                assert updated.split(section, 1)[1] == original.split(section, 1)[1]
        backups = list(Path(directory).glob('pacman.conf.nvgd-*'))
        assert len(backups) == 1 and backups[0].read_text() == original
        subprocess.run(['python3', '-c', isolated], check=True, capture_output=True)
        assert path.read_text() == updated
        assert len(list(Path(directory).glob('pacman.conf.nvgd-*'))) == 1
print('Releases URL, old-section migration, repository order, backup, idempotence: PASS (3 fixtures)')
