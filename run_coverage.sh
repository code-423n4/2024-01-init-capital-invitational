#!/bin/sh

# run forge coverage test 
forge coverage --report lcov

# remove unwanted files
lcov --remove ./lcov.info -o ./lcov.info.pruned 'contracts/.cache' 'tests/' 'contracts/mock/' 'contracts/common/library/' && genhtml ./lcov.info.pruned -o report --branch-coverage && open report/index.html
