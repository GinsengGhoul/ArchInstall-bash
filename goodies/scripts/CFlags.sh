#!/bin/sh
gcc -### -E - -march=native 2>&1 | sed -r '/cc1/!d;s/(")|(^.* - )//g;s/ -dumpbase -//'
