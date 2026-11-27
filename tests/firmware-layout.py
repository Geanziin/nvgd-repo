#!/usr/bin/env python3
"""Reject package ownership below the distribution-owned GA107 GSP symlink."""
import hashlib
import sys
import tarfile
from pathlib import Path

package = Path(sys.argv[1])
canonical = 'usr/lib/firmware/nvidia/ga102/gsp/sec2-bl-615.78.08.bin'
link = 'usr/lib/firmware/nvidia/ga107/gsp'
expected = 'a209bded1de8aec02548dd75daa37de6257521b0fb1c57c49c737b13f44a70d9'
with tarfile.open(package) as archive:
    members = {m.name.rstrip('/'): m for m in archive}
    assert not any(n == link or n.startswith(link + '/') for n in members), 'claims distribution symlink'
    member = members[canonical]
    assert member.isfile()
    assert hashlib.sha256(archive.extractfile(member).read()).hexdigest() == expected
    blobs = [n for n in members if n.startswith('usr/lib/firmware/gpu-unlock/610.43.03/') and n.endswith('.bin')]
    assert len(blobs) == 9
print('PASS: canonical SEC2 loader, no GA107 symlink ownership, nine unlock blobs')
