#!/bin/bash

#
# In case you have never used npm do
#
# npm install
#

CURR_DIR=$(pwd)

branch_name=`git branch | head | cut -d ' ' -f 2 | tail -n 1`

echo "-- Pushing code -- "
cd httpdocs/dist
git checkout $branch_name
git pull --rebase
cd $CURR_DIR

echo "-- Compiling Dist -- "
npm run build || exit 1

cd httpdocs/dist
git add *
git commit -m 'Update dist' || exit 1
echo "Dist committed"
git push || exit 1
echo "Dist pushed"
cd $CURR_DIR

git add httpdocs/dist
git commit -m 'Update dist' || exit 1
echo "Dist ref committed"
git push || exit 1
echo "Dist ref pushed"
