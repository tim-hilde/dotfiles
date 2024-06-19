#
# Copyright (c) 2017 Dean Jackson <deanishe@deanishe.net>
#
# MIT Licence. See http://opensource.org/licenses/MIT
#
# Created on 2017-12-18
#

"""ZotHero data models."""

from __future__ import print_function, absolute_import

import json
import logging

from .util import json_serialise, utf8encode


log = logging.getLogger(__name__)
log.addHandler(logging.NullHandler())


class AttrDict(dict):
    """Dictionary whose keys are also accessible as attributes."""

    def __init__(self, *args, **kwargs):
        """Create new `AttrDict`.

        Args:
            *args (objects): Arguments to `dict.__init__()`
            **kwargs (objects): Keyword arguments to `dict.__init__()`

        """
        super(AttrDict, self).__init__(*args, **kwargs)

    def __getattr__(self, key):
        """Look up attribute as dictionary key.

        Args:
            key (str): Dictionary key/attribute name.

        Returns:
            obj: Dictionary value for `key`.

        Raises:
            AttributeError: Raised if `key` isn't in dictionary.

        """
        if key not in self:
            raise AttributeError("AttrDict object has no attribute: %r" % key)

        return self[key]

    def __setattr__(self, key, value):
        """Add `value` to the dictionary under `key`.

        Args:
            key (str): Dictionary key/attribute name.
            value (obj): Value to store for `key`.

        """
        self[key] = value


class Entry(AttrDict):
    """A publication from the Zotero database.

    Attributes:
        id (int): Database ID for Entry
        key (unicode): The unique identifier for this Entry.
        title (unicode): The title of the Entry.
        date (unicode): Publication date in YYYY-MM-DD, YYYY-MM or YYYY
            format. The raw date string from Zotero is stored in
            ``zdata['date']``.
        year (int): The year Entry was published.
        modified (datetime.datetime): Time when Entry was last modified.
        library (int): Which library the Entry belongs to.
        type (unicode): The type of Entry, e.g. "journalArticle".
        creators (list): Sequence of `Creator` objects.
        zdata (dict): All Zotero data using unprocessed keys and values.
        collections (list): `Collection` objects the Entry belongs to.
        tags (list): Unicode tags belonging to Entry.
        attachments (list): Sequence of `Attachment` objects.
        notes (list): Plaintext (Unicode) Entry notes.
        abstract (unicode): Entry abstract.
        citekey (unicode or None): Better Bibtex citekey.

    """

    @classmethod
    def from_json(cls, js):
        """Deserialise an `Entry` from JSON."""
        data = json.loads(js)

        e = Entry(data)

        e.creators = [Creator(d) for d in e.creators]
        e.collections = [Collection(d) for d in e.collections]
        e.attachments = [Attachment(d) for d in e.attachments]

        return e

    def __init__(self, *args, **kwargs):
        """Create new `Entry`.

        Args:
            *args: Optional initialisation data. As for `dict`.
            **kwargs: Optional initialisation data. As for `dict`.

        """
        super(Entry, self).__init__(*args, **kwargs)

    @property
    def authors(self):
        """Creators whose type is ``author``.

        Returns:
            list: Sequence of `Creator` objects.

        """
        return [c for c in self.creators if c.type == 'author']

    @property
    def editors(self):
        """Creators whose type is ``editor``.

        Returns:
            list: Sequence of `Creator` objects.

        """
        return [c for c in self.creators if c.type == 'editor']

    @property
    def csl(self):
        """CSL data for `Entry` for converting to CSL-JSON.

        Returns:
            dict: Entry data converted to CSL types.

        """
        from .csl import entry_data
        return entry_data(self)

    @property
    def csljson(self):
        """CSL-JSON for `Entry`.

        Returns:
            str: JSON array containing CSL data for one `Entry`.

        """
        return json.dumps(self.csl, indent=2, sort_keys=True)

    def __str__(self):
        """Title, year and author(s) of `Entry`.

        Returns:
            str: UTF8-encoded string.

        """
        if isinstance(self, str):
            return self
        #return str(self).encode('utf-8', 'replace')
        #return unicode(self).encode('utf-8', 'replace')

    def __unicode__(self):
        """Title, year and author(s) of `Entry`.

        Returns:
            unicode: Description of `Entry`.

        """
        s = self.title
        if self.year:
            s += u' ({})'.format(self.year)

        authors = ', '.join([c.family for c in self.creators if c])

        if authors:
            s += ' by ' + authors

        return s

    def json(self):
        """Serialise `Entry` to JSON.

        Returns:
            str: JSON-encoded `Entry`.

        """
        return json.dumps(self, indent=2, sort_keys=True,
                          default=json_serialise)


class Attachment(AttrDict):
    """File attached to an `Entry`.

    NOTE: An Attachment may have either a URL or a path, but not
    both. The other attribute will be ``None``.

    Attributes:
        key (unicode): Unique identifier
        name (unicode): (File)name of Attachment
        path (unicode): Path to file
        url (unicode): URL of the Attachment

    """

    def __init__(self, *args, **kwargs):
        """Create new `Attachment` object.

        Args:
            *args: Optional initialisation data. As for `dict`.
            **kwargs: Optional initialisation data. As for `dict`.

        """
        super(Attachment, self).__init__(*args, **kwargs)


class Collection(AttrDict):
    """Collection `Entry` belongs to.

    Attributes:
        name (unicode): Name of Collection
        key (unicode): Unique identifier

    """

    def __init__(self, *args, **kwargs):
        """Create new `Collection` object.

        Args:
            *args: Optional initialisation data. As for `dict`.
            **kwargs: Optional initialisation data. As for `dict`.

        """
        super(Collection, self).__init__(*args, **kwargs)


class Creator(AttrDict):
    """Author/performer of `Entry`.

    Attributes:
        index (int): Priority of Creator
        given (unicode): Given name of Creator
        family (unicode): Family name of Creator
        type (unicode): Type of Creator, e.g. "author"

    """

    def __init__(self, *args, **kwargs):
        """Create new `Creator` object.

        Args:
            *args: Optional initialisation data. As for `dict`.
            **kwargs: Optional initialisation data. As for `dict`.

        """
        super(Creator, self).__init__(*args, **kwargs)


class CSLStyle(AttrDict):
    """A CSL style configuration.

    Attributes:
        hidden (bool): Whether the style is hidden (i.e. a parent style).
        name (unicode): Name of the style (extracted from the stylesheet).
        path (unicode): Path to the .csl file.
        parent_url (unicode): URL of parent style for dependent styles.
            ``None`` for independent styles.
        url (unicode): Canonical URL of the style.

    """

    @classmethod
    def from_json(cls, js):
        """Create a `CSLStyle` from a JSON object."""
        return cls(json.loads(js))

    def __init__(self, *args, **kwargs):
        """Create a new style.

        Args:
            *args: Optional initialisation data. As for `dict`.
            **kwargs: Optional initialisation data. As for `dict`.

        """
        super(CSLStyle, self).__init__(*args, **kwargs)

    @property
    def key(self):
        """Return unique key for style.

        Returns:
            unicode: Style key.

        """
        return self.url

    def __unicode__(self):
        """Return Unicode representation of style."""
        return u'[{}] {}'.format(self.key, self.name)

    def __str__(self):
        """Return UTF-8 representation of style."""
        if isinstance(self, str):
            return self
        
        
    def __repr__(self):
        """Code-like representation of style."""
        return 'CSLStyle(name={s.name!r}, path={s.path!r})'.format(s=self)
