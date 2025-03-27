
usage() {
    echo "Usage: $0 [-h] [-c CONFIG] [-p PROMPT]"
    echo "Options:"
    echo " -h               Show this help message"
    echo " -c CONFIG        The task to perform (default: config.yaml)"
    echo " -p PROMPT        The mode to use (default: default collaborator)"
}

PROMPT=""
CONFIG=""

while getopts ":p::" opts; do
    case ${opts} in
        c )
            CONFIG="--config $OPTARG"
            ;;
        p )
            PROMPT="--prompt $OPTARG"
            ;;
        : )
            echo "Option -$OPTARG requires an argument." >&2
            usage
            exit 1
            ;;
    esac
done


file_path=$(dirname $(readlink -f $BASH_SOURCE))

cd "$file_path"
if [[ ! -d "./venv" ]]; then
    python -m venv ./venv
    source ./venv/bin/activate
    pip install -r ./requirements.txt
    deactivate
fi

source ./venv/bin/activate
python3 -u ./server.py $PROMPT $CONFIG
deactivate
cd - > /dev/null
