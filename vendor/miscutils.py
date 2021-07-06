# This is a copy of function(s) we use from rpmUtils.miscutils from yum (yum.baseurl.org).
# This has no Python 3 version and is no longer included in Fedora (or, presumably, RHEL 8+).

# ---------------------------------------------------------------------

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# Copyright 2003 Duke University

def stringToVersion(verstring):
    if verstring in [None, '']:
        return (None, None, None)
    i = verstring.find(':')
    if i != -1:
        try:
            epoch = str(int(verstring[:i]))
        except ValueError:
            # look, garbage in the epoch field, how fun, kill it
            epoch = '0' # this is our fallback, deal
    else:
        epoch = '0'
    j = verstring.find('-')
    if j != -1:
        if verstring[i + 1:j] == '':
            version = None
        else:
            version = verstring[i + 1:j]
        release = verstring[j + 1:]
    else:
        if verstring[i + 1:] == '':
            version = None
        else:
            version = verstring[i + 1:]
        release = None
    return (epoch, version, release)
