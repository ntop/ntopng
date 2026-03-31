#!/bin/bash

CURR_DIR=$(pwd)

branch_name=$(git branch --show-current)
echo "Dist Branch: $branch_name"
echo "-- Cleaning up dist --"
cd httpdocs/dist
git fetch
git checkout -B "$branch_name" "origin/$branch_name"

echo "-- Compiling dist --"
cd "$CURR_DIR"
npm run build || exit 1

echo "-- Pushing dist --"
cd httpdocs/dist
git add -A
git commit -m 'Update dist' || exit 1
git push origin "$branch_name" || exit 1

echo "-- Pushing ref --"
cd "$CURR_DIR"
git add httpdocs/dist
git commit -m 'Update dist' || exit 1
git push || exit 1
