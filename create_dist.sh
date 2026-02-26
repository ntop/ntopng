#!/bin/bash

branch_name=`git branch | head | cut -d ' ' -f 2`

echo "-- Compiling Dist -- "
npm run build || exit 1

echo "-- Pushing code -- "
cd httpdocs/dist
git checkout $branch_name

git add *
git commit -m 'updated dist' || exit 1
echo "Committed"

git push || exit 1
echo "Pushed"
