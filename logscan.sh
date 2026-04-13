#!/bin/bash

pattern=$1
filename=$2

list=$(grep $pattern $filename)
count="$(printf %s\n "$list" | wc -l)"

echo "Summary:"
echo "Errors found: $count"
echo "Search results:"
printf '%s\n' "$list"
