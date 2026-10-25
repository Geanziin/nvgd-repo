#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo 'Run with sudo: sudo bash install.sh'
    exit 1
fi

if command -v pacman >/dev/null 2>&1; then
python3 - <<'PY'
import datetime, pathlib, re, shutil
path = pathlib.Path('/etc/pacman.conf')
original = path.read_text()
sections = re.split(r'(?m)(?=^\s*\[[^\]\n]+\]\s*$)', original)
kept = []
for section in sections:
    match = re.match(r'\s*\[([^\]]+)\]', section)
    if match and match[1] in ('nvgd', 'nvgd-dkms', 'nouveau-lab'):
        continue
    kept.append(section)
block = ('[nvgd]\n'
         'SigLevel = Optional TrustAll\n'
         'Server = https://geanziin.github.io/nvgd-repo/$arch\n'
         '\n')
# Put nvgd before every other repository, but after [options].
index = next((i for i, section in enumerate(kept)
              if re.match(r'\s*\[(?!options\])[^\]]+\]', section)), len(kept))
kept.insert(index, block)
updated = ''.join(kept)
if updated != original:
    backup = path.with_name('pacman.conf.nvgd-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    shutil.copy2(path, backup)
    path.write_text(updated)
    print('Backup:', backup)
print('Repository configured: [nvgd] -> https://geanziin.github.io/nvgd-repo/$arch')
PY

    if [[ "${1:-}" == --configure-only ]]; then
        exit 0
    fi

    # Full upgrade avoids mixing Arch repository snapshots.
    pacman -Syu --needed nvgd/nvgd-dkms nvgd/mesa-git nvgd/lib32-mesa-git \
        nvgd/gpu-screen-recorder-git nvgd/gpu-screen-recorder-ui-git \
        nvgd/gpu-screen-recorder-notification-git

    echo 'Installation complete. Reboot after changing the kernel module.'

elif command -v emerge >/dev/null 2>&1; then
    mkdir -p /etc/portage/repos.conf
    cat <<'EOF' > /etc/portage/repos.conf/nvgd.conf
[nvgd]
location = /var/db/repos/nvgd
sync-type = git
sync-uri = https://github.com/Geanziin/nvgd-repo.git
auto-sync = yes
EOF
    echo 'Gentoo overlay configured: [nvgd] -> /var/db/repos/nvgd'

    if [[ "${1:-}" == --configure-only ]]; then
        exit 0
    fi

    if command -v emaint >/dev/null 2>&1; then
        emaint sync -r nvgd
    else
        emerge --sync nvgd
    fi
    echo 'Sync complete. You can now emerge media-libs/mesa::nvgd and x11-drivers/nvgd-dkms::nvgd'
else
    echo 'Neither pacman nor emerge was detected. Please consult README.md for manual setup.'
    exit 1
fi
