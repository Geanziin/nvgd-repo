# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 meson

DESCRIPTION="Notification overlay for GPU Screen Recorder"
HOMEPAGE="https://github.com/Geanziin/gpu-screen-recorder-notification"
EGIT_REPO_URI="https://github.com/Geanziin/gpu-screen-recorder-notification.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND="
	media-video/gpu-screen-recorder
	x11-libs/libX11
	x11-libs/libXrandr
	media-libs/libglvnd
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-build/meson-0.59.0
	>=dev-build/ninja-1.8.2
	virtual/pkgconfig
"
