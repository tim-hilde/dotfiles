# encoding: utf-8
#
# Copyright (c) 2017 Dean Jackson <deanishe@deanishe.net>
#
# MIT Licence. See http://opensource.org/licenses/MIT
#
# Created on 2017-12-20
#

"""Put multiple data formats on the macOS pasteboard at the same time."""

from __future__ import print_function, absolute_import

from AppKit import NSPasteboard
from Foundation import NSData
import logging

from workflow.util import run_trigger
log = logging.getLogger(__name__)

# Some common UTIs
UTI_HTML = 'public.html'
UTI_TEXT = 'public.rtf'
UTI_PLAIN = 'public.utf8-plain-text'
UTI_URL = 'public.url'
UTI_URL_NAME = 'public.url-name'

# JXA script to simulate CMD+V keypress via Carbon.
# Unaffected by other modifiers the user may be holding down, unlike
# System Events.
PASTE_SCRIPT = """
ObjC.import('Carbon');

var source = $.CGEventSourceCreate($.kCGEventSourceStateCombinedSessionState);

var pasteCommandDown = $.CGEventCreateKeyboardEvent(source, $.kVK_ANSI_V, true);
$.CGEventSetFlags(pasteCommandDown, $.kCGEventFlagMaskCommand);
var pasteCommandUp = $.CGEventCreateKeyboardEvent(source, $.kVK_ANSI_V, false);

$.CGEventPost($.kCGAnnotatedSessionEventTap, pasteCommandDown);
$.CGEventPost($.kCGAnnotatedSessionEventTap, pasteCommandUp);

"""


def nsdata(s):
    """Return an NSData instance for string `s`."""
    if isinstance(s, str):
         s = s.encode('utf-8')
    else:
        s = str(s)
    log.debug ("str s is: %s" % s)
    return NSData.dataWithBytes_length_(s, len(s))


def set(contents):
    """Set the clipboard contents.

    `contents` should have the format:

        {
            'UTI': 'value',
            ...
        }

        e.g. `{'public.html': '<a href="...">...</a>'}`

    Each value must be a `unicode` or `str()`-able object.

    """
    for uti in contents:
        log.debug ("uti: {}, contents: {}".format (uti, contents[uti]))
        
    
    # pboard = NSPasteboard.generalPasteboard()
    # pboard.clearContents()
    # for uti in contents:
    #     #log.debug ("uti: %s" % uti)
    #     data = nsdata(contents[uti])
    #     #pboard.setData_forType_(data, uti.encode('utf-8'))
    #     pboard.setData_forType_(data, str(uti))


def paste():
    """Simulate CMD+V to paste clipboard."""
    run_trigger('paste')
    # This doesn't appear to work on Catalina :(
    # run_jxa(PASTE_SCRIPT)


