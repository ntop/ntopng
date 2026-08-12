#!/bin/bash

CURR_DIR=$(pwd)
CURR_BRANCH=$(git branch --show-current)

echo "Current Branch: $CURR_BRANCH"

echo "-- Cleaning up dist --"
cd httpdocs/dist
git reset --hard HEAD
git pull
git checkout -B "$CURR_BRANCH" "origin/$CURR_BRANCH"

echo "-- Compiling dist --"
cd "$CURR_DIR/pro"
npm run build || exit 1

echo "-- Pushing dist --"
cd "$CURR_DIR/httpdocs/dist"
git add -A
git commit -m 'Update dist' || exit 1
git push origin "$CURR_BRANCH" || exit 1

echo "-- Pushing ref --"
cd "$CURR_DIR"
git add httpdocs/dist
git commit -m 'Update dist' || exit 1
git push || exit 1
