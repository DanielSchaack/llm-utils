#!/bin/bash

usage() {
    echo "Usage: $0 [OPTIONS] [ARGUMENTS...]"
    echo "Options:"
    echo "  -h                 Show this help message"
    echo "  -i DRIVER          Install podman and required packages for Ollama GPU usage and Open-WebUI."
    echo "                     DRIVER must be 'nvidia' or 'amd'."
    echo "  -s                 Do not start Open-WebUI and Ollama. Opens a window in BROWSER (currently: chromium)."
    echo "  -S                 Start Open-WebUI and Ollama in a chosen BROWSER (default: chromium)."
    echo "  -e                 Stop Open-WebUI and Ollama."
    echo "  -u                 Upgrade Open-WebUI and Ollama by stopping, deleting, and pulling new versions from main."
}

BROWSER="chromium"
START=true

while getopts ":hi:sS:eu" opt; do
  case ${opt} in
    h ) 
      usage
      exit 0
      ;;
    i ) 
      SETUP=true
      DRIVER="$OPTARG"
      ;;
    s ) 
      START=false
      ;;
    S ) 
      START=true
      BROWSER="${OPTARG:-chromium}"
      ;;
    e ) 
      START=false
      END=true
      ;;
    u ) 
      UPGRADE=true
      ;;
    \? ) 
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

sleep_and_open_browser(){
    sleep 10
    "$BROWSER" "127.0.0.1:3000"
}

if [[ $SETUP ]]; then
    case $DRIVER in
        "nvidia")
            sudo pacman -Sy podman
            yay -Sy nvidia-container-toolkit
            podman network create llm
            podman run -d -p 127.0.0.1:3000:8080 --network=llm -e WEBUI_AUTH=False -e ENABLE_SIGNUP=false -e OLLAMA_BASE_URL=http://ollama:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
            # if needed, edit /etc/containers/registries.conf - unqualified... and add docker.io
            podman run -d --name ollama --gpus all -v ollama:/root/.ollama --network=llm -p 127.0.0.1:11434:11434 ollama/ollama
            ;;
        "amd")
            echo "Not yet implemented"
            # sudo pacman -Sy podman
            # yay -Sy nvidia-container-toolkit
            # podman network create llm
            # podman run -d -p 127.0.0.1:3000:8080 --network=llm -e WEBUI_AUTH=False -e ENABLE_SIGNUP=false -e OLLAMA_BASE_URL=http://ollama:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
            # podman run -d --name ollama --gpus all -v ollama:/root/.ollama --network=llm -p 127.0.0.1:11434:11434 ollama/ollama
            ;;
        *)
            echo "It is 'nvidia' or 'amd' you bum"
            ;;
    esac
fi

if [[ "$UPGRADE" = true ]]; then
    podman stop open-webui 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "Removing open-webui"
        podman rm open-webui
    fi
    podman pull ghcr.io/open-webui/open-webui:main
    podman create -p 127.0.0.1:3000:8080 --network=llm -e WEBUI_AUTH=False -e ENABLE_SIGNUP=false -e OLLAMA_BASE_URL=http://ollama:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main

    podman stop ollama 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "Removing ollama"
        podman rm ollama 
    fi
    podman pull ollama/ollama
    podman create --name ollama --gpus all -v ollama:/root/.ollama --network=llm -p 127.0.0.1:11434:11434 ollama/ollama
fi

if [[ "$START" = true ]]; then
    podman start open-webui 2>/dev/null
    if [[ $? -ne 0 ]]; then
        podman run -d -p 127.0.0.1:3000:8080 --network=llm -e WEBUI_AUTH=False -e ENABLE_SIGNUP=false -e OLLAMA_BASE_URL=http://ollama:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
    fi

    podman start ollama 2>/dev/null
    if [[ $? -ne 0 ]]; then
        podman run -d --name ollama --gpus all -v ollama:/root/.ollama --network=llm -p 127.0.0.1:11434:11434 ollama/ollama
    fi

    echo "Waiting 10 seconds for the containers to properly start"
    sleep_and_open_browser &
fi

if [[ "$END" = true ]]; then
    podman stop open-webui
    podman stop ollama
fi


