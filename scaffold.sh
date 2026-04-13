#!/bin/bash

dir=$1
echo "Creating directory ./$1"
mkdir ./$dir
echo "Entering directory ./$1"
cd $dir

echo "Creating README.md and .gitignore"
touch README
touch .gitignore

echo "Initializing git"
git init