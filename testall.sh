#!/bin/env bash

cases=0
success=0

while IFS= read -r label && IFS= read -r test; do
    echo -e "\e[95m$label\e[0m"

    arguments=$(echo "$label" | grep -oP '(--[a-z-]+)' | tr '\n' ' ')

    echo -e '\e[2m$ node build/main.js '"$arguments"'"'"$test"'"\e[22m'

    ((cases++))

    # shellcheck disable=SC2086
    if node --enable-source-maps build/main.js $arguments"$test"; then
        if [[ ${label#"# Valid"} != "$label" ]]; then
            ((success++))
            echo -e "\e[92mTest success\e[0m"
        else
            echo -e "\e[91mTest failed\e[0m"
        fi
    else
        if [[ ${label#"# Invalid"} != "$label" ]]; then
            ((success++))
            echo -e "\e[92mTest success\e[0m"
        else
            echo -e "\e[91mTest failed\e[0m"
        fi
    fi

    echo ""
done < cases.txt

echo "Test cases: $cases"
echo "Success: $success"
