#!/bin/bash

echo "Building package for ROOTLESS Jailbreak"
export THEOS_PACKAGE_SCHEME=rootless

make clean
make package FINALPACKAGE=1

unset THEOS_PACKAGE_SCHEME
