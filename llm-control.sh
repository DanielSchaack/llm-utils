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
    echo "  -m MODEL           Specify the model to use (default: mistral)"
    echo "                     Available options: mistral, devstral, qwen3, jan"
}

BROWSER="chromium"
START=true
PORT=8000
MODEL="mistral"
MODEL_DIR="$HOME/models/gguf"

declare -A MODEL_FILES=(
    ["mistral"]="mistralai_Devstral-Small-2507-Q6_K_L.gguf"
    ["devstral"]="mistralai_Devstral-Small-2507-Q6_K_L.gguf"
    ["qwen3"]="Qwen3-Coder-30B-A3B-Instruct-UD-Q5_K_XL.gguf"
    ["jan"]="janhq_Jan-v1-4B-Q6_K_L.gguf"
)

declare -A MODEL_SOURCES=(
    ["mistral"]="https://huggingface.co/bartowski/mistralai_Mistral-Small-3.2-24B-Instruct-2506-GGUF/resolve/main/mistralai_Mistral-Small-3.2-24B-Instruct-2506-Q6_K_L.gguf"
    ["mistral-mmproj"]="https://huggingface.co/bartowski/mistralai_Mistral-Small-3.2-24B-Instruct-2506-GGUF/resolve/main/mmproj-mistralai_Mistral-Small-3.2-24B-Instruct-2506-f16.gguf"
    ["mistral-jinja"]="https://huggingface.co/bartowski/mistralai_Mistral-Small-3.2-24B-Instruct-2506-GGUF/resolve/main/Mistral-Small-3.2-24B-Instruct-2506.jinja"
    ["devstral"]="https://huggingface.co/bartowski/mistralai_Devstral-Small-2507-GGUF/resolve/main/mistralai_Devstral-Small-2507-Q6_K_L.gguf"
    ["qwen3"]="https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/resolve/main/Qwen3-Coder-30B-A3B-Instruct-UD-Q5_K_XL.gguf"
    ["jan"]="https://huggingface.co/bartowski/janhq_Jan-v1-4B-GGUF/resolve/main/janhq_Jan-v1-4B-Q6_K_L.gguf"
)

declare -A MODEL_MMPROJS=(
    ["mistral"]="mmproj-mistralai_Mistral-Small-3.2-24B-Instruct-2506-f16.gguf"
    ["devstral"]=""
    ["qwen3"]=""
    ["jan"]=""
)

declare -A MODEL_TEMPLATES=(
    ["mistral"]="Mistral-Small-3.2-24B-Instruct-2506.jinja"
    ["devstral"]=""
    ["qwen3"]=""
    ["jan"]=""
)

declare -A MODEL_ALIASES=(
    ["mistral"]="Mistral"
    ["devstral"]="Devstral"
    ["qwen3"]="Qwen3-Coder"
    ["jan"]="Jan-V1"
)

while getopts ":hi:sS:eup:m:" opt; do
    case ${opt} in
    h)
        usage
        exit 0
        ;;
    i)
        SETUP=true
        DRIVER="$OPTARG"
        ;;
    s)
        START=false
        ;;
    S)
        START=true
        BROWSER="${OPTARG:-chromium}"
        ;;
    e)
        START=false
        END=true
        ;;
    u)
        UPGRADE=true
        ;;
    p)
        PORT="$OPTARG"
        ;;
    m)
        MODEL="$OPTARG"
        case "$MODEL" in
        mistral | devstral | qwen3 | jan) ;;
        *)
            echo "Invalid model: $model" >&2
            echo "Available models: mistral, devstral, qwen3" >&2
            usage
            exit 1
            ;;
        esac
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        usage
        exit 1
        ;;
    esac
done

OPENWEBUI_RUN_ARGS=" -p 127.0.0.1:3000:8080 --network=llm -e WEBUI_AUTH=False -e ENABLE_SIGNUP=false -v open-webui:/app/backend/data --name open-webui --restart always "
LLAMA_RUN_ARGS=" -d --ipc=host --network=llm -p $PORT:8000 --privileged --device=/dev/kfd --device=/dev/dri --device=/dev/mem --cap-add=SYS_PTRACE -v $MODEL_DIR:/models --name llama "

shift $((OPTIND - 1))

sleep_and_open_browser() {
    sleep 10
    "$BROWSER" "127.0.0.1:3000"
}

check_and_download_model() {
    local model_file="$1"
    local download_url="$2"
    local full_path="$MODEL_DIR/$model_file"

    if [[ ! -f "$full_path" ]]; then
        read -p "Model file not found: $full_path. Would you like to download it? (Y/n): " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            curl -L -o "$full_path" "$download_url"
        else
            exit 1
        fi
    fi
}

build_model_command() {
    local cmd=" "

    local model_file="${MODEL_FILES[$MODEL]}"
    if [[ -n "$model_file" ]]; then
        local model_source="${MODEL_SOURCES[$MODEL]}"
        check_and_download_model "$model_file" "$model_source"
        cmd+=" -m /models/$model_file"
    fi

    local mmp_file="${MODEL_MMPROJS[$MODEL]}"
    if [[ -n "$mmp_file" ]]; then
        local key="${MODEL}-mmproj"
        local model_source="${MODEL_SOURCES[$key]}"
        check_and_download_model "$mmp_file" "$model_source"
        cmd+=" --mmproj /models/$mmp_file"
    fi

    local template="${MODEL_TEMPLATES[$MODEL]}"
    if [[ -n "$template" ]]; then
        local key="${MODEL}-jinja"
        local model_source="${MODEL_SOURCES[$key]}"
        check_and_download_model "$template" "$model_source"
        cmd+=" --jinja --chat-template-file /models/$template"
    fi

    local alias="${MODEL_ALIASES[$MODEL]}"
    if [[ -n "$alias" ]]; then
        cmd+=" --alias $alias"
    fi

    # Add common parameters
    cmd+=" -ngl 100 --slots --port 8000 --host 0.0.0.0 -fa -ctk q8_0 -ctv q8_0 -c 32000 -n 8192"
    echo "$cmd"
}

if [[ $SETUP ]]; then
    # if needed, edit /etc/containers/registries.conf - unqualified... and add docker.io
    podman network create llm 2>/dev/null
    mkdir -p "$MODEL_DIR" 2>/dev/null
    case $DRIVER in
    "nvidia")
        sudo pacman -Sy podman
        yay -Sy nvidia-container-toolkit
        ;;
    "amd")
        sudo pacman -Sy podman
        yay -Sy rocm-hip-sdk rocm-opencl-sdk
        ;;
    *)
        echo "It is 'nvidia' or 'amd' you bum"
        ;;
    esac
fi

if [[ "$UPGRADE" = true ]]; then
    podman stop open-webui 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "Removing Open-WebUI"
        podman rm open-webui
    fi
    podman pull ghcr.io/open-webui/open-webui:main
    podman create $OPENWEBUI_RUN_ARGS ghcr.io/open-webui/open-webui:main

    podman stop llama 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "Removing llama"
        podman rm llama
    fi
    podman pull ghcr.io/ggml-org/llama.cpp:server-vulkan
    podman create $LLAMA_RUN_ARGS ghcr.io/ggml-org/llama.cpp:server-vulkan
    # echo "podman create $LLAMA_RUN_ARGS ghcr.io/ggml-org/llama.cpp:server-vulkan $LLAMA_EXEC_ARGS"
fi

if [[ "$START" = true ]]; then
    podman network create llm 2>/dev/null
    mkdir -p "$MODEL_DIR" 2>/dev/null

    podman start open-webui 2>/dev/null
    if [[ $? -ne 0 ]]; then
        podman run $OPENWEBUI_RUN_ARGS ghcr.io/open-webui/open-webui:main
    fi

    podman stop llama 2>/dev/null
    podman rm llama 2>/dev/null
    LLAMA_EXEC_ARGS="$(build_model_command)"
    podman run $LLAMA_RUN_ARGS ghcr.io/ggml-org/llama.cpp:server-vulkan $LLAMA_EXEC_ARGS

    echo "Waiting 10 seconds for the containers to properly start"
    sleep_and_open_browser &
fi

if [[ "$END" = true ]]; then
    podman stop open-webui
    podman stop llama
fi
