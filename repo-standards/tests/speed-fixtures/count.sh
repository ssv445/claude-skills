#!/bin/sh
# Fixture: a class's test command. Fails when <class>/fail exists, else passes.
[ ! -e "$1/fail" ]
