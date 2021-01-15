#!/bin/sh
# Autobootstrap script for Ubuntu
# bases on LARBS (<https://github.com/LukeSmithxyz/LARBS
# by Murad Bashirov <carlsonmu@gmail.com>
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

while getopts ":r:b:p:h" o; do case "${o}" in
    h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\n  -h: Show this message\\n" && exit 1 ;;
    r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit 1 ;;
    b) repobranch=${OPTARG} ;;
    p) progsfile=${OPTARG} ;;
    *) printf "Invalid option: -%s\\n" "$OPTARG" && exit 1 ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/spitfire-hash/dotfiles.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/spitfire-hash/bootstrap-ubuntu/master/progs.csv"
[ -z "$repobranch" ] && repobranch="master"

### FUNCTIONS ###
installpkg(){ apt install -y "$1" >/dev/null 2>&1 ;}

error(){ clear; printf "ERROR:\\n%s\\n" "$1" >&2; exit 1; }

welcomemsg() { \
     dialog --title "Welcome!" --msgbox "Welcome to ootstrapping Script for Debian/Ubuntu!\\n\\nThis script will automatically install some programs and dotfiles that I use\\n\\n-Murad" 10 60
     dialog --colors --title "Important Note!" --yes-label "All ready!" --no-label "Return..." --yesno "Be sure the computer you are using has current apt updates \\n\\nIf it does not have, the installation of some programs might fail." 8 70
}

getuserandpass() { \
     # Prompts user for new username an password.
     name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
     while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
          name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
     done
     pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
     pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
     while ! [ "$pass1" = "$pass2" ]; do
          unset pass2
          pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
          pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
     done ;}

usercheck() { \
     ! { id -u "$name" >/dev/null 2>&1; } ||
     dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. The script can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nScript will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that the script will change $name's password to the one you just gave." 14 70
}

preinstallmsg() { \
     dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time.\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit 1; }
}

adduserandpass() { \
     # Adds user `$name` with password $pass1.
     dialog --infobox "Adding user \"$name\"..." 4 50
     useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
     usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
     repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel "$(dirname "$repodir")"
     echo "$name:$pass1" | chpasswd
     unset pass1 pass2 ;}

maininstall() { # Installs all needed programs from main repo.
     dialog --title "Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
     installpkg "$1"
     }

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/# Bootstrap Script/d" /etc/sudoers
	echo "$* #Script" >> /etc/sudoers ;}

gitmakeinstall() {
     progname="$(basename "$1" .git)"
     dir="$repodir/$progname"
     dialog --title "Installation" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
     sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return 1 ; sudo -u "$name" git pull --force origin master;}
     cd "$dir" || exit 1
     make >/dev/null 2>&1
     make install >/dev/null 2>&1
     cd /tmp || return 1 ;}

pipinstall() { \
    dialog --title "Installation" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
    [ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
    yes | pip3 install "$1"
    }

releaseinstall() { \
    progname="$(echo "$1" | awk -F / '{ print $5 }')"
    dialog --title "Installation" --infobox "Installing \`$progname\` ($n of $total) via GitHub releases. $progname $2" 5 70
    curl -L $1 | tar xzC /usr/bin
}

debinstall() { \
    progname="$(echo "$1" | awk -F / '{ print $5 }')"
    dialog --title "Installation" --infobox "Installing \`$progname\` ($n of $total) via deb package. $progname $2" 5 70
    curl -L $1 | dpgk -i
}


installationloop() { \
    ([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
    total=$(wc -l < /tmp/progs.csv)
    while IFS=, read -r tag program comment; do
        n=$((n+1))
        echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
        case "$tag" in
            "G") gitmakeinstall "$program" "$comment" ;;
            "P") pipinstall "$program" "$comment" ;;
	    "R") releaseinstall "$program" "$comment" ;;
	    "D") depinstall "$program" "$comment" ;;
	    "GC") apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0 >/dev/null 2>&1 &&
                  apt-add-repository https://cli.github.com/packages >/dev/null 2>&1 &&
		  apt update >/dev/null 2>&1 &&
		  apt install gh >/dev/null 2>&1 ;;

            *) maininstall "$program" "$comment" ;;
        esac
    done < /tmp/progs.csv ;}

putgitrepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
    dialog --infobox "Downloading and installing config files..." 4 60
    [ -z "$3" ] && branch="master" || branch="$repobranch"
    dir=$(mktemp -d)
    [ ! -d "$2" ] && mkdir -p "$2"
    chown -R "$name":wheel "$dir" "$2"
    sudo -u "$name" git clone --recursive -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
    sudo -u "$name" cp -rfT "$dir" "$2"
    }

finalize(){ \
    dialog --infobox "Preparing welcome message..." 4 50
    dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\n\\n.t Murad" 12 80
    }


### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Debian distro. Install dialog.
apt install -y dialog || error "Are you sure you're running this as the root user, are on an Debian-based distribution and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

for x in curl build-essential git zsh; do
    dialog --title "Installation" --infobox "Installing \`$x\` which is required to install and configure other programs." 5 70
    installpkg "$x"
done

adduserandpass || error "Error adding username and/or password."

# Allow user to run sudo without password.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
rm -f "/home/$name/README.md" "/home/$name/LICENSE"
# Create default urls file if none exists.
[ ! -f "/home/$name/.config/newsboat/urls" ] && echo "http://lukesmith.xyz/rss.xml
https://notrelated.libsyn.com/rss
https://www.youtube.com/feeds/videos.xml?channel_id=UC2eYFnH61tmytImy1mTYvhA \"~Luke Smith (YouTube)\"
https://www.archlinux.org/feeds/news/" > "/home/$name/.config/newsboat/urls"
# make git ignore deleted LICENSE & README.md files
git update-index --assume-unchanged "/home/$name/README.md" "/home/$name/LICENSE"

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"


# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newperms "%wheel ALL=(ALL) ALL #LARBS
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount,/usr/bin/apt update"

# Last message! Install complete!
finalize
clear
