#!/bin/bash -e

#  Tool to create (and optionally install) Debian packages of i3-gaps.
#  Copyright (C) 2017  Gerhard A. Dittes
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Namespace: igd

# Variables

igd_BASEDIR="$(pwd)"
igd_GITDIR="${igd_BASEDIR}/i3-gaps"
igd_GITURL="https://www.github.com/Airblader/i3"
igd_TIMESTAMP="$(date +%Y%m%d%H%M%S)"
igd_JESSIE=-1

# Functions

igd_usage()
{
	printf "\nThis tool creates (and optionally installs) Debian packages of i3-gaps.\n\n"
	printf "Usage: ${0} [OPTION...]\n\n"
	printf "  -h, --help       show this help and quit\n"
	printf "      --config     print \"i3-gaps config\" recommendation\n\n"
}

igd_checkHelp()
{
	if [ ${#} -ge 1 ]; then
		case "${1}" in
		"-h"|"--help")
			igd_usage
			exit 0
			;;
		"--config")
			igd_printI3GapsConfig
			exit 0
			;;
		*)
			igd_usage
			exit 23
			;;
		esac
	fi
}

igd_log()
{
	local msg="${@}"
	tput setaf 3; printf "[igd] " >&2; tput sgr0
	tput setaf 7; printf "${msg}\n" >&2; tput sgr0
}

igd_readAndContinue()
{
	local msg="${@}"
	tput setaf 3; printf "[igd] "; tput sgr0
	tput setaf 7; printf "${msg}"; tput sgr0
	read -p " [RETURN]"
}

igd_question()
{
	local result=1 # false
	local question="${1}"
	local default="n"

	# ensure lowercase
	if [ ${#} -eq 2 ] && [ "${2}" = "y" -o "${2}" = "Y" ]; then
		default="y"
	fi

	tput setaf 3; printf "[igd] "; tput sgr0
	tput setaf 7; printf "${question}"; tput sgr0

	if [ ${default} = "y" ]; then
		printf " (Y/n): "
	else
		printf " (y/N): "
	fi

	read answer

	# ensure lowercase
	if [ "${answer}" = "Y" ]; then
		answer="y"
	elif [ "${answer}" = "N" ]; then
		answer="n"
	fi

	if [ ${default} = "y" ]; then
		if [ "${answer}" != "n" ]; then
			result=0 # true
		fi
	else
		if [ "${answer}" = "y" ]; then
			result=0 # true
		fi
	fi

	return ${result}
}

igd_startupHint()
{
	igd_readAndContinue "This tool creates (and optionally installs) Debian packages of i3-gaps..."
	igd_readAndContinue "This tool comes without any warranty and in the hope to be useful..."
}

igd_ensureI3ToBeInstalled()
{
	igd_log "Checking i3 installation..."

	if ! dpkg -s i3 &> /dev/null; then
		igd_readAndContinue "This tool assumes that you have \"i3\" already installed. Please do so..."
		exit 42
	fi
}

igd_checkSourcesList()
{
	igd_log "Checking sources.list(s) to contain sources (\"weak\")..."

	if ! grep --quiet -r "^ *deb-src.*\(\(debian\)\|\(ubuntu\)\|\(kali\)\)[/ ].*main" /etc/apt/sources.list*; then
		igd_readAndContinue "Please add necessary \"deb-src\" line(s) to your apt sources (and run an 'apt update')."
		exit 1
	fi
}

igd_detectDebianJessie()
{
	if grep --quiet ^8 /etc/debian_version; then
		igd_log "Debian jessie detected."
		igd_JESSIE=0
	else
		igd_log "Debian version != jessie, ignoring special treatment..."
		igd_JESSIE=1
	fi
}

igd_isJessie()
{
	if [ ${igd_JESSIE} -eq -1 ]; then
		igd_detectDebianJessie
	fi

	return ${igd_JESSIE}
}

igd_ensurePotentialJessieBackportsAvailability()
{
	igd_log "Checking sources.list(s) to contain jessie-backports (\"weak\")..."

	if ! grep --quiet -r "^ *deb-src.*-backports" /etc/apt/sources.list*; then
		igd_readAndContinue "Please add \"jessie-backport sources\" to your sources.list (and run an update)."
		igd_log "You can use the following lines to achieve that:"
		cat <<EOF
deb http://ftp.debian.org/debian/ jessie-backports main
deb-src http://ftp.debian.org/debian/ jessie-backports main
EOF
		exit 3
	fi
}

igd_handleJessieBackportsSpecialCase()
{
	if igd_isJessie; then
		igd_ensurePotentialJessieBackportsAvailability
	fi
}

igd_installBuildDeps()
{
	igd_readAndContinue "Installing (basic) build dependencies..."
	if igd_isJessie; then
		sudo apt-get -y build-dep i3-wm
	else
		sudo apt -y build-dep i3-wm
	fi

	igd_readAndContinue "Installing (additional) build dependencies..."
	sudo apt -y install \
		devscripts dpkg-dev \
		dh-autoreconf \
		libxcb-xrm-dev \
		libxcb-xkb-dev \
		libxkbcommon-dev \
		libxkbcommon-x11-dev
}

igd_ensureGitToBeInstalled()
{
	igd_log "Checking git installation..."

	if ! dpkg -s git &> /dev/null; then
		if igd_question "This tool assumes that you have \"git\" already installed. Install now?" "y"; then
			sudo apt-get -y install git
		else
			exit 44
		fi
	fi
}

igd_clone()
{
	if [ ! -d ${igd_GITDIR} ]; then
		igd_readAndContinue "Cloning i3 gaps into \"${igd_GITDIR}\"..."
		git clone ${igd_GITURL} ${igd_GITDIR}
	else
		igd_log "Skip cloning as ${igd_GITDIR} already exists."
	fi
}

igd_switchToGitDir()
{
	igd_log "Entering directory ${igd_GITDIR}..."
	cd ${igd_GITDIR}
}

igd_cleanUpGitStuff()
{
	igd_log "Cleaning up..."
	git reset --hard HEAD
	git clean -fdx
}

igd_prepareBranch()
{
	local branch="gaps"
	local alternative="gaps-next"

	if ! igd_question "Use branch \"${branch}\"? (\"${alternative}\" otherwise)" "y"; then
		branch=${alternative}
	fi

	git checkout ${branch}
	git pull
}

igd_updateDebianChangelog()
{
	igd_log "Updating Debian changelog..."

	DEBEMAIL="maestro.gerardo@gmail.com" DEBFULLNAME="Gerhard A. Dittes" \
		debchange --preserve --dist=unstable --local=gerardo+${igd_TIMESTAMP} "New upstream."
}

igd_fixRules()
{
	igd_log "Fix rules file..."
	cat <<EOF >>debian/rules

override_dh_install:
override_dh_installdocs:
override_dh_installman:
	dh_install -O--parallel
EOF
}

igd_buildDebianPackages()
{
	igd_readAndContinue "Build Debian packages..."
	dpkg-buildpackage -us -uc
}

igd_switchToBaseDir()
{
	igd_log "Entering directory ${igd_BASEDIR}..."
	cd ${igd_BASEDIR}
}

igd_installDebianPackages()
{
	local debs=$(echo i3_*${igd_TIMESTAMP}*deb i3-wm_*${igd_TIMESTAMP}*deb)
	igd_log "Result: ${debs}"
	if igd_question "Install created Debian packages?" "y"; then
		sudo dpkg -i ${debs}
	fi
}

igd_ensurePotentialJessieDependencyStuff()
{
	igd_readAndContinue "Correcting dependency stuff..."

	local f1="${igd_GITDIR}/debian/control"
	local f2="${igd_GITDIR}/configure.ac"
	sed -i 's/libcairo2-dev (>= 1\.14\.[0-9]*)/libcairo2-dev (>= 1\.14\.0)/g' ${f1}
	sed -i 's/cairo >= 1\.14\.[0-9]*/cairo >= 1\.14\.0/g' ${f2}
}

igd_handleJessieDependencySpecialCase()
{
	if igd_isJessie; then
		igd_ensurePotentialJessieDependencyStuff
	fi
}

igd_cleanUp()
{
	if igd_question "Remove created files?" "y"; then
		rm -v *${igd_TIMESTAMP}*
	fi
}

igd_printI3GapsConfig()
{
	cat <<EOF

### i3-gaps stuff ###

# Necessary for i3-gaps to work properly (pixel can be any value)
for_window [class="^.*"] border pixel 3

# Smart Gaps
smart_gaps on

# Smart Borders
smart_borders on

# Set inner/outer gaps
gaps inner 12
gaps outer -2

# Gaps mode
set \$mode_gaps Gaps: (o) outer, (i) inner
set \$mode_gaps_outer Outer Gaps: +|-|0 (local), Shift + +|-|0 (global)
set \$mode_gaps_inner Inner Gaps: +|-|0 (local), Shift + +|-|0 (global)
bindsym \$mod+Shift+g mode "\$mode_gaps"

mode "\$mode_gaps" {
        bindsym o      mode "\$mode_gaps_outer"
        bindsym i      mode "\$mode_gaps_inner"
        bindsym Return mode "default"
        bindsym Escape mode "default"
}

mode "\$mode_gaps_inner" {
        bindsym plus  gaps inner current plus 5
        bindsym minus gaps inner current minus 5
        bindsym 0     gaps inner current set 0

        bindsym Shift+plus  gaps inner all plus 5
        bindsym Shift+minus gaps inner all minus 5
        bindsym Shift+0     gaps inner all set 0

        bindsym Return mode "default"
        bindsym Escape mode "default"
}

mode "\$mode_gaps_outer" {
        bindsym plus  gaps outer current plus 5
        bindsym minus gaps outer current minus 5
        bindsym 0     gaps outer current set 0

        bindsym Shift+plus  gaps outer all plus 5
        bindsym Shift+minus gaps outer all minus 5
        bindsym Shift+0     gaps outer all set 0

        bindsym Return mode "default"
        bindsym Escape mode "default"
}

EOF
}

igd_configHintPart1()
{
	igd_readAndContinue "Please append the following lines to your i3-config and restart..."
	igd_printI3GapsConfig
}

igd_configHintPart2()
{
	igd_readAndContinue "...you can print them at any time later using \"${0} --config\"..."
}

igd_updatePotentialConfigs()
{
	local configs="${HOME}/.i3/config ${HOME}/.config/i3/config"

	for f in ${configs}; do
		if [ -w ${f} ] && igd_question "Or shall I do it for you now (file: ${f})?"; then
			igd_printI3GapsConfig >> ${f}
		fi
	done
}

main()
{
	igd_checkHelp ${@}
	igd_startupHint
	igd_ensureI3ToBeInstalled
	igd_checkSourcesList
	igd_detectDebianJessie
	igd_handleJessieBackportsSpecialCase
	igd_installBuildDeps
	igd_ensureGitToBeInstalled
	igd_clone
	igd_switchToGitDir
	igd_cleanUpGitStuff
	igd_prepareBranch
	igd_updateDebianChangelog
	igd_fixRules
	igd_handleJessieDependencySpecialCase
	igd_buildDebianPackages
	igd_switchToBaseDir
	igd_installDebianPackages
	igd_cleanUp
	igd_configHintPart1
	igd_configHintPart2
	igd_updatePotentialConfigs
}

main ${@}
