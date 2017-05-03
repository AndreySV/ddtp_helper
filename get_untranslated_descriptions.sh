#!/bin/sh
#
# Copyright (C) 2017: Andrey Skvortsov <andrej.skvortzov@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# On Debian systems, the full text of the GNU General Public
# License version 3 can be found in the file
# `/usr/share/common-licenses/GPL-3'.
#


set -e

set_env()
{
    DDTS_HOST=http://ddtp2.debian.net
    UNTRANSLATED_FILE=all_untranslated_desc.$LNG.txt
    POPCON_FILE=popcon.txt
    REVIEW_FILE=all_reviewed_desc.$LNG.txt
    TRANSLATE_FILE=sorted_untranslated_desc.$LNG.txt
    NUM_SHOW=20
}


need_to_update_file()
{
    local file=$1
    local update_interval_s=$2
    local update=0
    if [ ! -e  $UNTRANSLATED_FILE ]; then
        update=1
    else
        local now=$(date --date=$(date --iso-8601) +%s 2>/dev/null)
        local prev=$(date --date=$(date -r $file --iso-8601) +%s 2>/dev/null)
        local delta_s=$(($now-$prev))


        if [ $delta_s -ge $update_interval_s ]; then
            update=1
        fi
    fi
    echo $update
}

get_untraslated_desc()
{
    # update only once a day
    local update_interval_s=$((1*60*60*24))
    local update=$(need_to_update_file $UNTRANSLATED_FILE $update_interval_s)

    if [ $update -ne 0 ]; then
        echo "--------------------------------------------------------"
        echo " Receiving list of all untranslated package desciptions"
        echo " This may take some time..."
        echo "--------------------------------------------------------"
        echo ""

        wget -O - $DDTS_HOST/ddt.cgi?alluntranslatedpackages=$LNG | \
            sed 's/<pre>/<pre>\n/' | \
            grep untranslated | \
            awk -F '>' '{ print $2 }' | \
            sed  's/<\/a//' > $UNTRANSLATED_FILE
    fi
}

get_popcon_list()
{
    echo "--------------------------------------------------------"
    echo " Receiving popcon list"
    echo " This may take some time..."
    echo "--------------------------------------------------------"


    local POPCON_LINK=http://popcon.debian.org/by_vote.gz
    # POPCON_LINK=http://popcon.debian.org/by_inst.gz
    wget -O - $POPCON_LINK | \
        gunzip | \
        grep  '(.*)\s*$'  | \
        awk '{ print $2 }' > $POPCON_FILE
}


get_reviewed_desc()
{
    echo "--------------------------------------------------------"
    echo " Receiving list descriptions under review"
    echo "--------------------------------------------------------"
    echo ""

    wget -O - $DDTS_HOST/ddtss/index.cgi/$LNG | \
        sed -n '/This is because someone/{n;p}' | \
        sed 's/<\/h2>//;s/<ol>//;s/<\/ol>//;s/<\/div>//;s/None//;s/<\/li>/\n/g' | \
        sed 's/<\/a>.*$//' | \
        awk -F '>' '{print $3 }' > $REVIEW_FILE
}

get_sorted_untranslated_desc()
{
    get_untraslated_desc
    if [ ! -e $POPCON_FILE ]; then
        get_popcon_list
    fi
    get_reviewed_desc

    grep -F -x -f $UNTRANSLATED_FILE $POPCON_FILE | \
        grep -F -x -v -f $REVIEW_FILE > $TRANSLATE_FILE
    rm $REVIEW_FILE

    echo ""
    echo ""
    echo "--------------------------------------------------------"
    echo " First $NUM_SHOW untranslated descriptions"
    echo "--------------------------------------------------------"
    head -n $NUM_SHOW $TRANSLATE_FILE

    echo ""
    echo "Full list of untranslated package descriptions"
    echo "sorted by popcon rank is saved in $TRANSLATE_FILE"
}


print_help()
{
    local cmd=$(basename $0)

    echo "Usage: $cmd lang"
    echo ""
    echo "For example:"
    echo " $cmd ru"
    echo ""
    echo "Sorted by popcon rank list of untranslated package description"
    echo "is saved in $TRANSLATE_FILE"
}




LNG="$1"
set_env
if [ "$LNG" = "" ]; then
    print_help
    exit 1
fi
get_sorted_untranslated_desc
