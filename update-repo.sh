#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="${LAB_DIR:-/home/gean/Documents/nouveau-lab}"
if [[ "${1:-}" == --publish ]] && ! git -C "$REPO_DIR" diff --cached --quiet; then
    echo 'Refusing to publish with pre-existing staged changes.' >&2
    exit 1
fi
SELECTED_FILE="$(mktemp)"
trap 'rm -f "$SELECTED_FILE"' EXIT
export REPO_DIR LAB_DIR SELECTED_FILE

# Read package metadata: glob ordering is not Arch version ordering.
python3 - <<'PY'
import os, pathlib, shutil, subprocess, tarfile
root = pathlib.Path(os.environ['REPO_DIR']) / 'x86_64'
root.mkdir(exist_ok=True)
lab = pathlib.Path(os.environ['LAB_DIR']) / 'packaging'
packages = {
    'mesa-git': 'mesa-git-lab',
    'lib32-mesa-git': 'lib32-mesa-git',
    'nvgd-dkms': 'nvgd-dkms',
    'gpu-screen-recorder-git': 'gpu-screen-recorder-git',
    'gpu-screen-recorder-ui-git': 'gpu-screen-recorder-ui-git',
    'gpu-screen-recorder-notification-git': 'gpu-screen-recorder-notification-git',
}
selected = []
for name, directory in packages.items():
    best = None
    for path in list((lab / directory).glob('*.pkg.tar.zst')) + list(root.glob('*.pkg.tar.zst')):
        fields = subprocess.check_output(['pacman', '-Qp', '--', str(path)], text=True).split()
        if fields[0] != name:
            continue
        version = fields[1]
        if best is None or int(subprocess.check_output(['vercmp', version, best[0]], text=True)) > 0:
            best = (version, path)
    if best is None:
        raise SystemExit(f'Missing package: {name}; refusing to publish an incomplete repository')
    version, source = best
    # GitHub Release asset names replace ':' with '.'. Use the same filename
    # in Pages and the pacman database; keep the epoch in package metadata.
    dest = root / source.name.replace(':', '.')
    if source.resolve() != dest.resolve():
        shutil.copy2(source, dest)
    print(f'{name}: {version}')
    selected.append(str(dest))
# Content check: the selected nvgd-dkms must actually carry the unlock
# (a build without firmware would otherwise be published silently as
# "with unlock"). Fail the whole run when the content is missing.
nvgd = [p for p in selected if '/nvgd-dkms-' in p]
assert len(nvgd) == 1, f'expected one nvgd-dkms package, got {nvgd}'
with tarfile.open(nvgd[0], 'r:*') as tf:
    names = tf.getnames()
blobs = [n for n in names if n.startswith('usr/lib/firmware/gpu-unlock/610.43.03/') and n.endswith('.bin')]
if len(blobs) != 9:
    raise SystemExit(f'nvgd-dkms {nvgd[0]} has {len(blobs)}/9 gpu-unlock blobs; refusing to publish')
if not any(n.startswith('usr/src/nvgd-1.0.0/tensor_unlock/') for n in names):
    raise SystemExit(f'nvgd-dkms {nvgd[0]} has no tensor_unlock/ in usr/src; refusing to publish')
if not any(n == 'usr/lib/firmware/nvidia/ga107/gsp/sec2-bl-615.78.08.bin' for n in names):
    raise SystemExit(f'nvgd-dkms {nvgd[0]} has no sec2-bl at ga107/gsp; refusing to publish')
print(f'nvgd-dkms content OK: 9/9 gpu-unlock blobs, tensor_unlock/ in usr/src, sec2-bl at ga107/gsp')
pathlib.Path(os.environ['SELECTED_FILE']).write_text('\n'.join(selected) + '\n')
# repo-add replaces entries by package name. Include exactly one version of
# every supported package, including lib32, instead of adding all archives.
subprocess.run(['repo-add', str(root / 'nvgd.db.tar.gz'), *selected], check=True)
PY

if [[ "${1:-}" == --publish ]]; then
    mapfile -t selected_pkgs < "$SELECTED_FILE"
    # Publish every referenced package before replacing the public database.
    # Do not add binary archives to Git; pacman downloads them from Releases.
    if ! gh release view packages --repo Geanziin/nvgd-repo >/dev/null 2>&1; then
        gh release create packages --repo Geanziin/nvgd-repo --title "nvgd packages" --notes "Arch/CachyOS binary repository."
    fi
    gh release upload packages "${selected_pkgs[@]}" \
        --repo Geanziin/nvgd-repo --clobber
    gh release upload packages \
        "$REPO_DIR"/x86_64/nvgd.db "$REPO_DIR"/x86_64/nvgd.files \
        "$REPO_DIR"/x86_64/nvgd.db.tar.gz "$REPO_DIR"/x86_64/nvgd.files.tar.gz \
        --repo Geanziin/nvgd-repo --clobber
    git -C "$REPO_DIR" add -- .gitignore \
        x86_64/nvgd.db x86_64/nvgd.files x86_64/nvgd.db.tar.gz x86_64/nvgd.files.tar.gz \
        README.md install.sh update-repo.sh tests metadata
    git -C "$REPO_DIR" add -u -- packaging profiles media-libs media-video x11-drivers
    if ! git -C "$REPO_DIR" diff --cached --quiet; then
        git -C "$REPO_DIR" commit -m "[nvgd] update validated packages and Releases repository" -m "Generated-by: LLM"
    fi
    git -C "$REPO_DIR" pull --rebase origin main
    git -C "$REPO_DIR" push origin main
fi

rm -f "$SELECTED_FILE"
echo 'Repository generated. Publish with ./update-repo.sh --publish.'
echo 'Clients can update with sudo pacman -Syu; no partial upgrade is performed here.'
