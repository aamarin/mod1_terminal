#!/bin/bash

pattern=$1
filename=$2

list=$(grep "$pattern" "$filename")
if [ -z "$list" ]; then
  count=0
else
  count="$(printf '%s\n' "$list" | wc -l)"
fi

echo "Summary:"
echo "Errors found: $count"
echo "Search results:"
printf '%s\n' "$list"
