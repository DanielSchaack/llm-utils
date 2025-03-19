#!/bin/bash

TASK="autocorrect"
MODE="buffered"

usage() {
    echo "Usage: $0 [-h] [-t TASK] [-m MODE]"
    echo "Options:"
    echo " -h                 Show this help message"
    echo " -t TASK            The task to perform (default: autocorrect)"
    echo " -m MODE            The mode to use (default: buffered)"
}

while getopts ":hm:t:" opts; do
    case ${opts} in
        h )
            usage
            exit 0
            ;;
        t )
            TASK="$OPTARG"
            ;;
        m )
            MODE="$OPTARG"
            ;;
        \? )
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
        : )
            echo "Option -$OPTARG requires an argument." >&2
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

file_path=$(dirname $(readlink -f $BASH_SOURCE))

cd "$file_path"
if [[ ! -d "./venv" ]]; then
    python -m venv ./venv
    source ./venv/bin/activate
    pip install -r ./requirements.txt
    deactivate
fi

source ./venv/bin/activate
while read -r -p "Input to be worked on: " input; do
    [[ -z "$input" ]] && continue
    python3 -u ./ollama_generate.py "$TASK" "$MODE" "$input"
done
deactivate
cd - #> /dev/null
