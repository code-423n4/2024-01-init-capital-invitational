#!/bin/sh

cloc contracts --by-file contracts --fullpath --not-match-d="contracts/.cache|contracts/interfaces" --not-match-f="Log|Mock|Pyth|Lens|Center"