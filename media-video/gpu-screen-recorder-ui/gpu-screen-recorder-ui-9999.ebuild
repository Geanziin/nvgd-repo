# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 meson xdg

DESCRIPTION="GTK UI for GPU Screen Recorder"
HOMEPAGE="https://github.com/Geanziin/gpu-screen-recorder-ui"
EGIT_REPO_URI="https://github.com/Geanziin/gpu-screen-recorder-ui.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND="
	media-video/gpu-screen-recorder
	x11-libs/gtk+:3
	media-libs/libglvnd
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-build/meson-0.59.0
	>=dev-build/ninja-1.8.2
	virtual/pkgconfig
"
