# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 linux-mod-r1

DESCRIPTION="nvgd (live git): Next-Gen NVIDIA Driver with GSP P0 Boost for Turing+ GPUs (GTX 16xx, RTX 20/30/40)"
HOMEPAGE="https://github.com/Geanziin/nvgd-dkms"
EGIT_REPO_URI="https://github.com/Geanziin/nvgd-dkms.git"

LICENSE="GPL-2 MIT"
SLOT="0"
KEYWORDS=""

IUSE="+dkms"

RDEPEND="
	sys-kernel/linux-firmware
	dkms? ( sys-kernel/dkms )
"
DEPEND="
	virtual/linux-sources
"

CONFIG_CHECK="~DRM ~DRM_NOUVEAU"

src_compile() {
	if ! use dkms; then
		local modlist=( nouveau=video/drm/nouveau:drivers/gpu/drm/nouveau )
		local modargs=( KDIR="${KV_OUT_DIR}" )
		linux-mod-r1_src_compile
	fi
}

src_install() {
	if use dkms; then
		local dest="/usr/src/nvgd-${PV}"
		dodir "${dest}"
		cp -r drivers/gpu/drm/nouveau/* "${ED}${dest}/" || die
		insinto "${dest}"
		doins dkms.conf Makefile
	else
		linux-mod-r1_src_install
	fi

	# Modprobe configuration to prioritize nvgd over generic nouveau
	insinto /etc/modprobe.d
	newins "${FILESDIR}/nvgd.conf" nvgd.conf 2>/dev/null || true
}
