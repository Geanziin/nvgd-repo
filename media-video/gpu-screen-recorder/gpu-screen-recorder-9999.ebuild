# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 meson

DESCRIPTION="GPU Screen Recorder with native VA-API NVENC support"
HOMEPAGE="https://github.com/Geanziin/gpu-screen-recorder"
EGIT_REPO_URI="https://github.com/Geanziin/gpu-screen-recorder.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND="
	media-video/ffmpeg:=[vaapi]
	media-libs/libva:=
	x11-libs/libX11
	x11-libs/libXrandr
	x11-libs/libXfixes
	x11-libs/libXcomposite
	media-libs/libglvnd
	media-libs/libpulse
	dev-libs/wayland
	sys-apps/dbus
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-build/meson-0.59.0
	>=dev-build/ninja-1.8.2
	virtual/pkgconfig
"
