# encoding: utf-8
#
# Copyright (c) 2017 Dean Jackson <deanishe@deanishe.net>
#
# MIT Licence. See http://opensource.org/licenses/MIT
#
# Created on 2017-12-15
#

"""Common helper functions."""

from __future__ import print_function, absolute_import

from contextlib import contextmanager
from datetime import date, datetime
#from HTMLParser import HTMLParser
from html.parser import HTMLParser
import logging
import os
from os.path import getmtime
import re
from shutil import copyfile
import time
from unicodedata import normalize

log = logging.getLogger(__name__)

# Regex to match Zotero date values
match_date = re.compile(r'(\d\d\d\d)-(\d\d)-(\d\d).*').match


SQLITE_DATE_FMT = '%Y-%m-%d %H:%M:%S'


def dt2sqlite(dt):
    """Convert `datetime` to Sqlite time string.

    Format string is `SQLITE_DATE_FMT`.

    Args:
        dt (datetime): `datetime` object to convert.

    Returns:
        str: Sqlite-formatted datetime string.

    """
    return dt.strftime(SQLITE_DATE_FMT)


def sqlite2dt(s):
    """Convert Sqlite time string to `datetime` object.

    Format string is `util.SQLITE_DATE_FMT`. Microseconds
    are dropped on the floor.

    Args:
        s (str): Sqlite datetime string.

    Returns:
        datetime: `datetime` equivalent of `s`.

    """
    s = s.split('.')[0]
    return datetime.strptime(s, SQLITE_DATE_FMT)


class HTMLText(HTMLParser):
    """Extract text from HTML.

    Strips all tags from HTML.

    Attributes:
        data (list): Accumlated text content.

    """

    @classmethod
    def strip(cls, html):
        """Extract text from HTML.

        Args:
            html (unicode): HTML to process.
            decode (bool, optional): Decode from UTF-8 to Unicode.

        Returns:
            unicode: Text content of HTML.

        """
        p = cls()
        p.feed(html)
        
        #log.debug (html)
        return str(p)
        #return unicode(p)

    def __init__(self):
        """Create new HTMLText."""
        super().__init__()
        self.reset()
        self.data = []

    def handle_data(self, s):
        """Callback for contents of HTML tags.

        Args:
            s (unicode): Text from between HTML tags.
        """
        self.data.append(unicodify(s))

    # def __str__(self):
    #     """Return text UTF-8 encoded."""
    #     if isinstance(self, str):
    #          return self
        #return str(self)
        #return str(self).encode('utf-8', 'replace')
        #return unicode(self).encode('utf-8', 'replace')

    def __unicode__(self):
        """Return text as Unicode."""
        return u''.join(self.data)


def strip_tags(html):
    """Strip tags from HTML.

    Args:
        html (unicode): HTML text.

    Returns:
        unicode: Text contained in HTML.

    """
    return HTMLText.strip(html)


def copyifnewer(source, copy):
    """Replace path `copy` with a copy of file at `source`.

    Returns path to `copy`, overwriting it first with a copy of
    `source` if `source` is newer or if `copy` doesn't exist.

    Args:
        source (str): Path to original file
        copy (str): Path to copy

    Returns:
        str: Path to copy

    """
    if not os.path.exists(copy) or getmtime(source) > getmtime(copy):
        log.debug('[util] copying %r to %r ...',
                  shortpath(source), shortpath(copy))
        copyfile(source, copy)

    return copy


def unicodify(s, encoding='utf-8'):
    """Ensure ``s`` is Unicode.

    Returns Unicode unchanged, decodes bytestrings and calls `unicode()`
    on anything else.

    Args:
        s (basestring): String to convert to Unicode.
        encoding (str, optional): Encoding to use to decode bytestrings.

    Returns:
        unicode: Decoded Unicode string.

    """
    #if isinstance(s, unicode):
    if isinstance(s, str):
        return s

    # if isinstance(s, str):
    #     return s.decode(encoding, 'replace')

    return str(s)
    #return unicode(s)


def utf8encode(s):
    """Ensure string is an encoded bytestring."""
    if isinstance(s, str):
        return s

    # if isinstance(s, unicode):
    #     return s.encode('utf-8', 'replace')

    return str(s)


def asciify(s):
    """Ensure string only contains ASCII characters.

    Args:
        s (basestring): Unicode or bytestring.

    Returns:
        unicode: String containing only ASCII characters.

    """
    u = normalize('NFD', unicodify(s))
    s = u.encode('us-ascii', 'ignore')
    return unicodify(s)


def parse_date(datestr):
    """Parse a Zotero date into YYYY-MM-DD, YYYY-MM or YYYY format.

    Zotero dates are in the format "YYYY-MM-DD <in words>",
    where <in words> may be the year, month and year or full
    date depending on whether month and day are set.

    Args:
        datestr (str): Date from Zotero database

    Returns:
        unicode: Parsed date if ``datestr``.

    """
    if not datestr:
        return None

    m = match_date(datestr)
    if not m:
        return datestr[:4]  # YYYY
    try:
        return u'-'.join(m.groups())
    except ValueError:
        return None


def json_serialise(obj):
    """Serialise `date` objects.

    JSON serialisation helper to be passed as the ``default`` argument
    to `json.dump`.

    Args:
        obj (object): Anything JSON can't serialise

    Returns:
        str: ISO date format

    Raises:
        TypeError: Raised if ``obj`` is not a `datetime.date`

    """
    if isinstance(obj, date):
        return obj.isoformat()
    raise TypeError('Type %s is not serialisable' % type(obj))


_subunsafe = re.compile(r'[^a-z0-9\.-]').sub

_subdashes = re.compile(r'-+').sub


def safename(name):
    """Make a name filesystem-safe."""
    name = asciify(name).lower()
    name = _subunsafe('-', name)
    name = _subdashes('-', name)
    return unicodify(name)


def shortpath(p):
    """Replace ``$HOME`` in path with ~."""
    if not p:
        return p

    h = os.path.expanduser(u'~')
    return p.replace(h, '~')


@contextmanager
def timed(name=None):
    """Context manager that logs execution time."""
    name = name or ''
    start_time = time.time()
    yield
    log.info('[%0.2fs] %s', time.time() - start_time, name)


def time_since(ts):
    """Human-readable time since timestamp ``ts``."""
    if not ts:
        return 'never'

    units = ('secs', 'mins', 'hours')
    i = 0
    n = time.time() - ts

    while i < len(units) - 1:

        if n > 60:
            n /= 60
            i += 1

        else:
            break

    return '{:0.1f} {} ago'.format(n, units[i])
