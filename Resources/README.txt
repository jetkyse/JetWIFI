Optional resources for JetWIFI.

To extend MAC-vendor coverage beyond the built-in common-vendor table, place the
IEEE OUI list here as "oui.csv" with one entry per line:

    AABBCC,Vendor Name
    FCFBFB,Apple, Inc.

OUILookup loads it automatically at runtime (see Sources/Discovery/OUILookup.swift).
No code changes needed.
