#!/bin/bash

# Instructions
# this script is used to create the ntopng GUI dist
# 1. Pull ntopng dist under ../ https://github.com/ntop/ntopng-dist.git
# run ./create_dist.sh to create and push the compiled dist directly

echo "** Changing to ntopng-dist directory"
cd ../ntopng-dist/ || exit 1
echo "Current directory: $(pwd)"

# Pull the latest changes and rebase
git pull --rebase || exit 1
echo "Pulled latest changes"

echo "** Changing to ntopng directory"
cd ../ntopng/ || exit 1
echo "Current directory: $(pwd)"

echo "-- Compiling Dist -- "
make dist-ntopng
echo "-------------------- "

echo "** Changing to ntopng-dist directory"

# Checkout old dist
cd ../ntopng-dist/ || exit 1
git checkout ntopng.js

# Copy the new dist file after pulling the updates
cp ../ntopng/httpdocs/dist/ntopng.js ./ || exit 1
echo "Copied ntopng.js"


git add ntopng.js || exit 1

git commit -m 'updated dist' || exit 1
echo "Committed"


git push || exit 1
echo "Pushed"
