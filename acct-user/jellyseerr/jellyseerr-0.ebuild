# Copyright 2019-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit acct-user

KEYWORDS="~amd64 ~arm ~arm64 ~x86"

DESCRIPTION="user for jellyseerr"
ACCT_USER_ID=-1
ACCT_USER_HOME=/var/lib/jellyseerr
ACCT_USER_GROUPS=( jellyseerr )

acct-user_add_deps
