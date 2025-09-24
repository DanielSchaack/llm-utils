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
    echo "  -r                 Disables Embedding/RAG"
    echo "  -u                 Upgrade Open-WebUI and Ollama by stopping, deleting, and pulling new versions from main."
    echo "  -m MODEL           Specify the model to use (default: mistral)"
    echo "                     Available options under -m ?"
    echo "  -d                 Specify the model to use for speculative decoding. Only applies when specified. This disables multimodal input. (default: voxtrals)"
}

BROWSER="chromium"
START=true
EMBEDDING=true
EMBEDDING_MODEL="nomic-embed"
PORT=8000
MODEL="mistral"
SPECULATIVE_DECODING=false
SPECULATIVE_MODEL="mistral"
MODEL_DIR="$HOME/models/gguf"

declare -A MODEL_FILES=(
    ["mistral"]="mistralai_Mistral-Small-3.2-24B-Instruct-2506-Q6_K_L.gguf"
    ["devstral"]="mistralai_Devstral-Small-2507-Q6_K_L.gguf"
    ["voxtral"]="mistralai_Voxtral-Small-24B-2507-Q6_K_L.gguf"
    ["voxtrals"]="mistralai_Voxtral-Mini-3B-2507-Q6_K_L.gguf"
    ["gemma3s"]="google_gemma-3-270m-it-Q6_K_L.gguf"
    ["qwen3"]="Qwen3-Coder-30B-A3B-Instruct-UD-Q5_K_XL.gguf"
    ["qwen3d"]="Qwen3-Coder-Instruct-DRAFT-0.75B-32k-Q4_0.gguf"
    ["jan"]="janhq_Jan-v1-4B-Q6_K_L.gguf"
    ["nomic-embed"]="nomic-embed-text-v2-moe-q8_0.gguf"
)

declare -A MODEL_SOURCES=(
    ["mistral"]="https://huggingface.co/bartowski/mistralai_Mistral-Small-3.2-24B-Instruct-2506-GGUF/resolve/main/mistralai_Mistral-Small-3.2-24B-Instruct-2506-Q6_K_L.gguf"
    ["mistral-mmproj"]="https://huggingface.co/bartowski/mistralai_Mistral-Small-3.2-24B-Instruct-2506-GGUF/resolve/main/mmproj-mistralai_Mistral-Small-3.2-24B-Instruct-2506-f16.gguf"
    ["mistral-jinja"]="https://huggingface.co/bartowski/mistralai_Mistral-Small-3.2-24B-Instruct-2506-GGUF/resolve/main/Mistral-Small-3.2-24B-Instruct-2506.jinja"
    ["devstral"]="https://huggingface.co/bartowski/mistralai_Devstral-Small-2507-GGUF/resolve/main/mistralai_Devstral-Small-2507-Q6_K_L.gguf"
    ["voxtral"]="https://huggingface.co/bartowski/mistralai_Voxtral-Small-24B-2507-GGUF/resolve/main/mistralai_Voxtral-Small-24B-2507-Q6_K_L.gguf"
    ["voxtral-mmproj"]="https://huggingface.co/bartowski/mistralai_Voxtral-Small-24B-2507-GGUF/resolve/main/mmproj-mistralai_Voxtral-Small-24B-2507-f16.gguf"
    ["voxtrals"]="https://huggingface.co/bartowski/mistralai_Voxtral-Mini-3B-2507-GGUF/resolve/main/mistralai_Voxtral-Mini-3B-2507-Q6_K_L.gguf"
    ["voxtrals-mmproj"]="https://huggingface.co/bartowski/mistralai_Voxtral-Mini-3B-2507-GGUF/resolve/main/mmproj-mistralai_Voxtral-Mini-3B-2507-f16.gguf"
    ["gemma3s"]="https://huggingface.co/bartowski/google_gemma-3-270m-it-GGUF/resolve/main/google_gemma-3-270m-it-Q6_K_L.gguf"
    ["qwen3"]="https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/resolve/main/Qwen3-Coder-30B-A3B-Instruct-UD-Q5_K_XL.gguf"
    ["qwen3d"]="https://huggingface.co/jukofyork/Qwen3-Coder-Instruct-DRAFT-0.75B-GGUF/resolve/main/Qwen3-Coder-Instruct-DRAFT-0.75B-32k-Q4_0.gguf"
    ["jan"]="https://huggingface.co/bartowski/janhq_Jan-v1-4B-GGUF/resolve/main/janhq_Jan-v1-4B-Q6_K_L.gguf"
    ["nomic-embed"]="https://huggingface.co/ggml-org/Nomic-Embed-Text-V2-GGUF/resolve/main/nomic-embed-text-v2-moe-q8_0.gguf"
)

declare -A MODEL_MMPROJS=(
    ["mistral"]="mmproj-mistralai_Mistral-Small-3.2-24B-Instruct-2506-f16.gguf"
    ["devstral"]=""
    ["voxtral"]="mmproj-mistralai_Voxtral-Small-24B-2507-f16.gguf"
    ["voxtrals"]="mmproj-mistralai_Voxtral-Mini-3B-2507-f16.gguf"
    ["gemma3s"]=""
    ["qwen3"]=""
    ["qwen3d"]=""
    ["jan"]=""
    ["nomic-embed"]=""
)

declare -A MODEL_TEMPLATES=(
    ["mistral"]="Mistral-Small-3.2-24B-Instruct-2506.jinja"
    ["devstral"]=""
    ["voxtral"]=""
    ["voxtrals"]=""
    ["gemma3s"]=""
    ["qwen3"]=""
    ["qwen3d"]=""
    ["jan"]=""
    ["nomic-embed"]=""
)

declare -A MODEL_ALIASES=(
    ["mistral"]="Mistral"
    ["devstral"]="Devstral"
    ["voxtral"]="Voxtral"
    ["voxtrals"]="Voxtral-Small"
    ["gemma3s"]="Gemma3-Small"
    ["qwen3"]="Qwen3-Coder"
    ["qwen3d"]="Qwen3-Coder-Draft"
    ["jan"]="Jan-V1"
    ["nomic-embed"]="Nomic-Embed"
)

while getopts ":hi:sS:erup:m:d:" opt; do
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
    r)
        EMBEDDING=false
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
        mistral | devstral | voxtral | voxtrals | qwen3 | jan) ;;
        *)
            echo "Invalid model: $model" >&2
            echo "Available models: mistral, devstral, voxtral, voxtrals, qwen3, jan" >&2
            usage
            exit 1
            ;;
        esac
        ;;
    d)
        SPECULATIVE_DECODING=true
        SPECULATIVE_MODEL="$OPTARG"
        case "$SPECULATIVE_MODEL" in
        voxtrals | qwen3d | gemma3s | jan) ;;
        *)
            echo "Invalid model: $model" >&2
            echo "Available models for speculative decoding: voxtrals, qwen3d, gemma3s, jan" >&2
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

# if needed, edit /etc/containers/registries.conf - unqualified... and add docker.io
WEB_SEARCH_IMAGE_NAME="searxng"
WEB_SEARCH_IMAGE_PATH="ghcr.io/searxng/searxng:latest"
WEB_SEARCH_RUN_ARGS=" --replace -p 127.0.0.1:8888:8080 --network=llm -e BASE_URL=http://127.0.0.1:8888/ -e INSTANCE_NAME=SharkSearch -e SEARXNG_LIMITER=False -v $HOME/.config/searxng/:/etc/searxng/ -v $HOME/.cache/searxng/:/etc/data/ --name $WEB_SEARCH_IMAGE_NAME "

EMBED_IMAGE_NAME="embed"
EMBED_IMAGE_PATH="ghcr.io/ggml-org/llama.cpp:server-vulkan"
EMBED_RUN_ARGS=" --ipc=host --network=llm -p 127.0.0.1:8001:8000 --privileged --device=/dev/kfd --device=/dev/dri --device=/dev/mem --cap-add=SYS_PTRACE -v $MODEL_DIR:/models --name $EMBED_IMAGE_NAME "
EMBED_EXEC_CONFIG=" --embedding -ngl 100 --slots --metrics --port 8000 --host 0.0.0.0 -fa on "

INFERENCE_IMAGE_NAME="llama"
INFERENCE_IMAGE_PATH="ghcr.io/ggml-org/llama.cpp:server-vulkan"
INFERENCE_RUN_ARGS=" --ipc=host --network=llm -p 127.0.0.1:$PORT:8000 --privileged --device=/dev/kfd --device=/dev/dri --device=/dev/mem --cap-add=SYS_PTRACE -v $MODEL_DIR:/models --name $INFERENCE_IMAGE_NAME "
INFERENCE_EXEC_CONFIG=" -ngl 100 --slots --metrics --port 8000 --host 0.0.0.0 -fa on -ctk q8_0 -ctv q8_0 -c 24000 -n -1 --batch-size 8192 "

# TODO: add default config as env
UI_IMAGE_NAME="open-webui"
UI_IMAGE_PATH="ghcr.io/open-webui/open-webui:slim"
UI_RUN_ARGS=" -p 127.0.0.1:3000:8080 --network=llm -e WEBUI_AUTH=False -e ENABLE_SIGNUP=false -e ENABLE_RAG_WEB_SEARCH=True -e RAG_WEB_SEARCH_ENGINE=$WEB_SEARCH_IMAGE_NAME -e RAG_WEB_SEARCH_RESULT_COUNT=3 -e RAG_WEB_SEARCH_CONCURRENT_REQUESTS=10 -e SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query> -v open-webui:/app/backend/data --name $UI_IMAGE_NAME --restart always "

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

download_and_append() {
    local file="$1"
    local key="$2"
    local flag="$3"
    local extra="$4"

    if [[ -n "$file" ]]; then
        local model_source="${MODEL_SOURCES[$key]}"
        check_and_download_model "$file" "$model_source"
        cmd+=" ${flag} /models/$file${extra}"
    fi
}

build_model_command() {
    local cmd=" "
    local model_to_use="${1:-$MODEL}"

    download_and_append "${MODEL_FILES[$model_to_use]}" "$model_to_use" "-m"
    if [[ "$SPECULATIVE_DECODING" == "true" ]]; then
        download_and_append "${MODEL_FILES[$SPECULATIVE_MODEL]}" "$SPECULATIVE_MODEL" "--model-draft" " --gpu-layers-draft 100 --draft-p-min 0.9 --draft-n-min 0 --ctx-size-draft 8192"
    else # only use multimodal input without speculative decoding
        download_and_append "${MODEL_MMPROJS[$model_to_use]}" "${model_to_use}-mmproj" "--mmproj"
    fi

    download_and_append "${MODEL_TEMPLATES[$model_to_use]}" "${model_to_use}-jinja" "--jinja --chat-template-file"
    local alias="${MODEL_ALIASES[$model_to_use]}"
    if [[ -n "$alias" ]]; then
        cmd+=" --alias $alias"
    fi

    echo "$cmd"
}

if [[ $SETUP ]]; then
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
    podman stop $WEB_SEARCH_IMAGE_NAME 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "Removing $WEB_SEARCH_IMAGE_NAME"
        podman rm $WEB_SEARCH_IMAGE_NAME
    fi
    podman pull $WEB_SEARCH_IMAGE_PATH
    podman create $WEB_SEARCH_RUN_ARGS $WEB_SEARCH_IMAGE_PATH

    podman stop $UI_IMAGE_NAME 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "Removing Open-WebUI"
        podman rm $UI_IMAGE_NAME
    fi
    podman pull $UI_IMAGE_PATH
    podman create $UI_RUN_ARGS $UI_IMAGE_PATH

    podman stop $INFERENCE_IMAGE_NAME 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "Removing $INFERENCE_IMAGE_NAME"
        podman rm $INFERENCE_IMAGE_NAME
    fi
    podman pull $INFERENCE_IMAGE_PATH
    podman create $INFERENCE_RUN_ARGS $INFERENCE_IMAGE_PATH

    podman stop $EMBED_IMAGE_NAME 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "Removing $EMBED_IMAGE_NAME"
        podman rm $EMBED_IMAGE_NAME
    fi
    if [[ "$INFERENCE_IMAGE_PATH" != "$EMBED_IMAGE_PATH" ]]; then
        podman pull $EMBED_IMAGE_PATH
    fi
    podman create $EMBED_RUN_ARGS $EMBED_IMAGE_PATH

fi

if [[ "$START" = true ]]; then
    podman network create llm 2>/dev/null
    mkdir -p "$MODEL_DIR" "$HOME/.cache/searxng/" "$HOME/.config/searxng/" 2>/dev/null

    podman start $WEB_SEARCH_IMAGE_NAME 2>/dev/null
    if [[ $? -ne 0 ]]; then
        podman stop $WEB_SEARCH_IMAGE_NAME 2>/dev/null
        podman rm $WEB_SEARCH_IMAGE_NAME 2>/dev/null
        podman run -d $WEB_SEARCH_RUN_ARGS $WEB_SEARCH_IMAGE_PATH
    fi

    podman start $UI_IMAGE_NAME 2>/dev/null
    if [[ $? -ne 0 ]]; then
        podman stop $UI_IMAGE_NAME 2>/dev/null
        podman rm $UI_IMAGE_NAME 2>/dev/null
        podman run -d $UI_RUN_ARGS $UI_IMAGE_PATH
    fi

    podman stop $INFERENCE_IMAGE_NAME 2>/dev/null
    podman rm $INFERENCE_IMAGE_NAME 2>/dev/null
    INFERENCE_EXEC_ARGS="$INFERENCE_EXEC_CONFIG$(build_model_command)"
    podman run -d $INFERENCE_RUN_ARGS $INFERENCE_IMAGE_PATH $INFERENCE_EXEC_ARGS

    if [[ "$EMBEDDING" = true ]]; then
        podman stop $EMBED_IMAGE_NAME 2>/dev/null
        podman rm $EMBED_IMAGE_NAME 2>/dev/null
        EMBED_EXEC_ARGS="$EMBED_EXEC_CONFIG$(build_model_command $EMBEDDING_MODEL)"
        podman run -d $EMBED_RUN_ARGS $EMBED_IMAGE_PATH $EMBED_EXEC_ARGS
    fi

    echo "Waiting 10 seconds for the containers to properly start"
    sleep_and_open_browser &
fi

if [[ "$END" = true ]]; then
    podman stop $UI_IMAGE_NAME
    podman stop $INFERENCE_IMAGE_NAME
    podman stop $WEB_SEARCH_IMAGE_NAME
    podman stop $EMBED_IMAGE_NAME
fi
