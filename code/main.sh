#!/bin/bash

FLOXAGENT_CONFIG_DIR="/root/.config/FloxAgent"
PROVIDERS_FILE="${FLOXAGENT_CONFIG_DIR}/providers.json"

RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

ensure_config_dir() {
  [ ! -d "$FLOXAGENT_CONFIG_DIR" ] && mkdir -p "$FLOXAGENT_CONFIG_DIR"
  [ ! -f "$PROVIDERS_FILE" ] && echo "[]" > "$PROVIDERS_FILE"
}

_spinner_pid=""
_spinner_chars="/-\|"

show_spinner() {
  local msg="$1"
  exec 3>&2 2>/dev/null
  (
    echo -n "$msg "
    i=0
    while true; do
      printf "%s" "${_spinner_chars:$i:1}"
      sleep 0.1
      i=$(( (i + 1) % ${#_spinner_chars} ))
      printf "\b"
    done
  ) &
  _spinner_pid=$!
  exec 2>&3 3>&-
}

hide_spinner() {
  if [ -n "$_spinner_pid" ]; then
    exec 3>&2 2>/dev/null
    kill "$_spinner_pid" 2>/dev/null
    wait "$_spinner_pid" 2>/dev/null
    exec 2>&3 3>&-
  fi
  _spinner_pid=""
  printf "\r\033[K"
}

providers_menu() {
  while :
  do
    clear
    echo "FloxAgent V1.0 Providers Menu"
    echo
    echo "[1] Add Provider"
    echo "[2] Remove Provider"
    echo "[0] Back"
    printf "Choice: "
    read -r choice

    case "$choice" in
      1)
        clear
        echo "Add New Provider"
        echo "------------------"

        provider_name=""
        while [ -z "$provider_name" ]; do
          printf "Provider Name? (e.g., OpenAI, VoidAI): "
          read -r provider_name
          if [ -z "$provider_name" ]; then
            echo -e "${RED}Provider Name cannot be empty. Please try again.${NC}"
            sleep 1
          fi
        done

        models=""
        while [ -z "$models" ]; do
          printf "Which models should exist? (e.g., gpt-5.2,gemini-3-pro): "
          read -r models
          if [ -z "$models" ]; then
            echo -e "${RED}Models cannot be empty. Please try again.${NC}"
            sleep 1
          fi
        done

        api_type="OpenAI Compatible"
        echo "Which API type is it?"
        echo "[1] OpenAI Compatible (Default)"
        printf "Choice (Enter '1' or press Enter): "
        read -r api_type_input

        if [ "$api_type_input" != "1" ] && [ -n "$api_type_input" ]; then
          echo -e "${RED}Invalid choice. Defaulting to 'OpenAI Compatible'.${NC}"
          sleep 1
        fi

        api_url=""
        while [ -z "$api_url" ]; do
          printf "API Url? (e.g., https://api.voidai.app/v1/chat/completions): "
          read -r api_url
          if [ -z "$api_url" ]; then
            echo -e "${RED}API URL cannot be empty. Please try again.${NC}"
            sleep 1
          fi
        done

        api_key=""
        while [ -z "$api_key" ]; do
          printf "API Key? (e.g., sk-voidai-...): "
          read -r api_key
          if [ -z "$api_key" ]; then
            echo -e "${RED}API Key cannot be empty. Please try again.${NC}"
            sleep 1
          fi
        done

        ensure_config_dir

        NEW_PROVIDER=$(jq -n \
          --arg name "$provider_name" \
          --arg models "$models" \
          --arg api_type "$api_type" \
          --arg api_url "$api_url" \
          --arg api_key "$api_key" \
          '{name: $name, models: $models, api_type: $api_type, api_url: $api_url, api_key: $api_key}')

        jq ". + [$NEW_PROVIDER]" "$PROVIDERS_FILE" > "$PROVIDERS_FILE.tmp" && mv "$PROVIDERS_FILE.tmp" "$PROVIDERS_FILE"

        echo "Provider added successfully!"
        sleep 1
        ;;

      2)
        clear
        echo "Remove Provider"
        echo "-----------------"

        ensure_config_dir

        PROVIDERS=$(jq -c . "$PROVIDERS_FILE")
        NUM_PROVIDERS=$(echo "$PROVIDERS" | jq 'length')

        if [ "$NUM_PROVIDERS" -eq 0 ]; then
          echo -e "${RED}No providers to remove.${NC}"
          sleep 1
          continue
        fi

        echo "Existing Providers:"
        echo "-------------------"

        for i in $(seq 0 $((NUM_PROVIDERS - 1))); do
          PROVIDER_NAME=$(echo "$PROVIDERS" | jq -r ".[$i].name")
          echo "[$((i + 1))] $PROVIDER_NAME"
        done

        echo "[0] Back"
        echo "-------------------"
        printf "Enter the number of the provider to remove (or '0' to go back): "
        read -r index_to_remove

        if [ "$index_to_remove" = "0" ]; then
          continue
        elif ! [[ "$index_to_remove" =~ ^[0-9]+$ ]] || [ "$index_to_remove" -lt 1 ] || [ "$index_to_remove" -gt "$NUM_PROVIDERS" ]; then
          echo -e "${RED}Invalid selection.${NC}"
          sleep 1
          continue
        fi

        ACTUAL_INDEX=$((index_to_remove - 1))

        jq "del(.[$ACTUAL_INDEX])" "$PROVIDERS_FILE" > "$PROVIDERS_FILE.tmp" && mv "$PROVIDERS_FILE.tmp" "$PROVIDERS_FILE"

        echo "Provider removed successfully!"
        sleep 1
        ;;

      0)
        clear
        break
        ;;

      *)
        clear
        ;;
    esac
  done
}

execute_read_tool() {
  local file_to_read="$1"
  local full_path="$WORKSPACE_DIR/$file_to_read"

  echo -e "${CYAN}[Running Tool READ]${NC}" >&2

  if [ -f "$full_path" ]; then
    cat "$full_path"
  else
    echo "Error: File '$file_to_read' not found in workspace directory."
  fi
}

execute_list_tool() {
  echo -e "${CYAN}[Running Tool LIST]${NC}" >&2
  ls -la "$WORKSPACE_DIR" 2>/dev/null || echo "Error: Could not list workspace directory."
}

request_edit_permission() {
  local file_to_edit="$1"
  local full_path="$WORKSPACE_DIR/$file_to_edit"
  local answer
  local lowered

  echo -e "${CYAN}[Running Tool EDIT]${NC}" >&2

  if [ -e /dev/tty ]; then
    printf "Do you allow the AI to edit %s? y/n or Yes/No: " "$file_to_edit" > /dev/tty
    read -r answer < /dev/tty
  else
    printf "Do you allow the AI to edit %s? y/n or Yes/No: " "$file_to_edit" >&2
    read -r answer
  fi

  lowered=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

  if [ "$lowered" = "y" ] || [ "$lowered" = "yes" ]; then
    echo "$file_to_edit" >> "$EDIT_PERMISSIONS_FILE"

    if [ -f "$full_path" ]; then
      echo "Edit allowed by user for '$file_to_edit'."
      echo
      echo "Current file content:"
      cat "$full_path"
    else
      echo "Edit allowed by user for '$file_to_edit'."
      echo
      echo "File does not exist yet. Create the full file content."
    fi

    echo
    echo "Now return the complete edited file content using exactly this format:"
    echo "EDIT $file_to_edit"
    echo "---CONTENT---"
    echo "complete file content here"
    echo "---END---"
  else
    echo "Edit denied by user."
  fi
}

apply_edit_tool() {
  local file_to_edit="$1"
  local content="$2"
  local full_path="$WORKSPACE_DIR/$file_to_edit"
  local dir_path

  echo -e "${CYAN}[Running Tool EDIT]${NC}" >&2

  if [ ! -f "$EDIT_PERMISSIONS_FILE" ] || ! grep -Fxq "$file_to_edit" "$EDIT_PERMISSIONS_FILE"; then
    echo "Edit denied: no user permission for '$file_to_edit'."
    return
  fi

  dir_path=$(dirname "$full_path")
  [ ! -d "$dir_path" ] && mkdir -p "$dir_path"

  if printf "%s" "$content" > "$full_path"; then
    grep -Fxv "$file_to_edit" "$EDIT_PERMISSIONS_FILE" > "$EDIT_PERMISSIONS_FILE.tmp" 2>/dev/null || true
    mv "$EDIT_PERMISSIONS_FILE.tmp" "$EDIT_PERMISSIONS_FILE" 2>/dev/null || true
    echo "Edit applied successfully to '$file_to_edit'."
  else
    echo "Error: Could not edit '$file_to_edit'."
  fi
}

request_create_permission() {
  local file_to_create="$1"
  local full_path="$WORKSPACE_DIR/$file_to_create"
  local answer
  local lowered

  echo -e "${CYAN}[Running Tool CREATE]${NC}" >&2

  if [ -e /dev/tty ]; then
    printf "Do you allow the AI to create %s? y/n or Yes/No: " "$file_to_create" > /dev/tty
    read -r answer < /dev/tty
  else
    printf "Do you allow the AI to create %s? y/n or Yes/No: " "$file_to_create" >&2
    read -r answer
  fi

  lowered=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

  if [ "$lowered" = "y" ] || [ "$lowered" = "yes" ]; then
    if [ -e "$full_path" ]; then
      echo "Create denied: file '$file_to_create' already exists. Use EDIT instead."
      return
    fi

    echo "$file_to_create" >> "$CREATE_PERMISSIONS_FILE"

    echo "Create allowed by user for '$file_to_create'."
    echo
    echo "Now return the complete file content using exactly this format:"
    echo "CREATE $file_to_create"
    echo "---CONTENT---"
    echo "complete file content here"
    echo "---END---"
  else
    echo "Create denied by user."
  fi
}

apply_create_tool() {
  local file_to_create="$1"
  local content="$2"
  local full_path="$WORKSPACE_DIR/$file_to_create"
  local dir_path

  echo -e "${CYAN}[Running Tool CREATE]${NC}" >&2

  if [ ! -f "$CREATE_PERMISSIONS_FILE" ] || ! grep -Fxq "$file_to_create" "$CREATE_PERMISSIONS_FILE"; then
    echo "Create denied: no user permission for '$file_to_create'."
    return
  fi

  if [ -e "$full_path" ]; then
    echo "Create denied: file '$file_to_create' already exists. Use EDIT instead."
    return
  fi

  dir_path=$(dirname "$full_path")
  [ ! -d "$dir_path" ] && mkdir -p "$dir_path"

  if printf "%s" "$content" > "$full_path"; then
    grep -Fxv "$file_to_create" "$CREATE_PERMISSIONS_FILE" > "$CREATE_PERMISSIONS_FILE.tmp" 2>/dev/null || true
    mv "$CREATE_PERMISSIONS_FILE.tmp" "$CREATE_PERMISSIONS_FILE" 2>/dev/null || true
    echo "Create applied successfully to '$file_to_create'."
  else
    echo "Error: Could not create '$file_to_create'."
  fi
}

execute_delete_tool() {
  local file_to_delete="$1"
  local full_path="$WORKSPACE_DIR/$file_to_delete"
  local answer
  local lowered

  echo -e "${CYAN}[Running Tool DELETE]${NC}" >&2

  if [ -e /dev/tty ]; then
    printf "Do you allow the AI to delete %s? y/n or Yes/No: " "$file_to_delete" > /dev/tty
    read -r answer < /dev/tty
  else
    printf "Do you allow the AI to delete %s? y/n or Yes/No: " "$file_to_delete" >&2
    read -r answer
  fi

  lowered=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

  if [ "$lowered" = "y" ] || [ "$lowered" = "yes" ]; then
    if [ ! -e "$full_path" ]; then
      echo "Delete failed: file '$file_to_delete' not found."
      return
    fi

    if [ -d "$full_path" ]; then
      echo "Delete denied: '$file_to_delete' is a directory."
      return
    fi

    if rm -f "$full_path"; then
      echo "Delete applied successfully to '$file_to_delete'."
    else
      echo "Error: Could not delete '$file_to_delete'."
    fi
  else
    echo "Delete denied by user."
  fi
}

execute_bash_tool() {
  local bash_command="$1"
  local answer
  local lowered
  local output
  local status

  echo -e "${CYAN}[Running Tool BASH]${NC}" >&2

  if [ -e /dev/tty ]; then
    printf "Do you allow the AI to run this bash command? y/n or Yes/No\n%s\nChoice: " "$bash_command" > /dev/tty
    read -r answer < /dev/tty
    printf "\033[3A\033[J" > /dev/tty
  else
    printf "Do you allow the AI to run this bash command? y/n or Yes/No\n%s\nChoice: " "$bash_command" >&2
    read -r answer
  fi

  lowered=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

  if [ "$lowered" = "y" ] || [ "$lowered" = "yes" ]; then
    output=$(cd "$WORKSPACE_DIR" && bash -c "$bash_command" 2>&1)
    status=$?

    echo "Exit status: $status"
    echo
    echo "$output"
  else
    echo "Bash command denied by user."
  fi
}

process_tool_calls() {
  local response="$1"
  local tool_results=""
  local found_tool=false
  local lines=()
  local i=0
  local line
  local trimmed

  mapfile -t lines <<< "$response"

  while [ "$i" -lt "${#lines[@]}" ]; do
    line="${lines[$i]}"
    trimmed=$(echo "$line" | xargs)

    if [[ "$trimmed" == "LIST" ]]; then
      found_tool=true

      local list_content
      list_content=$(execute_list_tool)

      tool_results="${tool_results}

[Workspace file listing]:
$list_content"

      i=$((i + 1))
      continue
    fi

    if [[ "$trimmed" =~ ^READ[[:space:]]+(.+)$ ]]; then
      found_tool=true

      local filename="${BASH_REMATCH[1]}"
      filename=$(echo "$filename" | xargs)

      local file_content
      file_content=$(execute_read_tool "$filename")

      tool_results="${tool_results}

[File content of '$filename']:
$file_content"

      i=$((i + 1))
      continue
    fi

    if [[ "$trimmed" =~ ^EDIT[[:space:]]+(.+)$ ]]; then
      found_tool=true

      local filename="${BASH_REMATCH[1]}"
      filename=$(echo "$filename" | xargs)

      local next_index=$((i + 1))
      local next_trimmed=""

      if [ "$next_index" -lt "${#lines[@]}" ]; then
        next_trimmed=$(echo "${lines[$next_index]}" | xargs)
      fi

      if [ "$next_trimmed" = "---CONTENT---" ]; then
        local j=$((i + 2))
        local edit_content=""

        while [ "$j" -lt "${#lines[@]}" ]; do
          local end_trimmed
          end_trimmed=$(echo "${lines[$j]}" | xargs)

          if [ "$end_trimmed" = "---END---" ]; then
            break
          fi

          edit_content="${edit_content}${lines[$j]}"
          edit_content="${edit_content}"$'\n'
          j=$((j + 1))
        done

        edit_content="${edit_content%$'\n'}"

        local edit_result
        edit_result=$(apply_edit_tool "$filename" "$edit_content")

        tool_results="${tool_results}

[Edit result]:
$edit_result"

        i=$((j + 1))
        continue
      else
        local permission_result
        permission_result=$(request_edit_permission "$filename")

        tool_results="${tool_results}

[Edit permission result]:
$permission_result"

        i=$((i + 1))
        continue
      fi
    fi

    if [[ "$trimmed" =~ ^CREATE[[:space:]]+(.+)$ ]]; then
      found_tool=true

      local filename="${BASH_REMATCH[1]}"
      filename=$(echo "$filename" | xargs)

      local next_index=$((i + 1))
      local next_trimmed=""

      if [ "$next_index" -lt "${#lines[@]}" ]; then
        next_trimmed=$(echo "${lines[$next_index]}" | xargs)
      fi

      if [ "$next_trimmed" = "---CONTENT---" ]; then
        local j=$((i + 2))
        local create_content=""

        while [ "$j" -lt "${#lines[@]}" ]; do
          local end_trimmed
          end_trimmed=$(echo "${lines[$j]}" | xargs)

          if [ "$end_trimmed" = "---END---" ]; then
            break
          fi

          create_content="${create_content}${lines[$j]}"
          create_content="${create_content}"$'\n'
          j=$((j + 1))
        done

        create_content="${create_content%$'\n'}"

        local create_result
        create_result=$(apply_create_tool "$filename" "$create_content")

        tool_results="${tool_results}

[Create result]:
$create_result"

        i=$((j + 1))
        continue
      else
        local permission_result
        permission_result=$(request_create_permission "$filename")

        tool_results="${tool_results}

[Create permission result]:
$permission_result"

        i=$((i + 1))
        continue
      fi
    fi

    if [[ "$trimmed" =~ ^DELETE[[:space:]]+(.+)$ ]]; then
      found_tool=true

      local filename="${BASH_REMATCH[1]}"
      filename=$(echo "$filename" | xargs)

      local delete_result
      delete_result=$(execute_delete_tool "$filename")

      tool_results="${tool_results}

[Delete result]:
$delete_result"

      i=$((i + 1))
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*BASH[[:space:]]+(.+)$ ]]; then
      found_tool=true

      local bash_command="${BASH_REMATCH[1]}"

      local bash_result
      bash_result=$(execute_bash_tool "$bash_command")

      tool_results="${tool_results}

[Bash result]:
$bash_result"

      i=$((i + 1))
      continue
    fi

    i=$((i + 1))
  done

  if [ "$found_tool" = true ]; then
    echo "$tool_results"
  fi
}

run_floxagent() {
  clear

  echo "FloxAgent V1.0 Run Agent"
  echo "------------------------"

  ensure_config_dir

  PROVIDERS=$(jq -c . "$PROVIDERS_FILE")
  NUM_PROVIDERS=$(echo "$PROVIDERS" | jq 'length')

  if [ "$NUM_PROVIDERS" -eq 0 ]; then
    echo -e "${RED}Error: No providers configured. Please add one first.${NC}"
    sleep 2
    clear
    return
  fi

  WORKSPACE_DIR=""

  while [ -z "$WORKSPACE_DIR" ]; do
    printf "Which Workspace Directory should be used? (Press Enter for default /root/FloxAgent): "
    read -r user_input_dir

    if [ -z "$user_input_dir" ]; then
      WORKSPACE_DIR="/root/FloxAgent"
      echo "Using default workspace directory: $WORKSPACE_DIR"
    else
      WORKSPACE_DIR="$user_input_dir"
    fi

    if [ ! -d "$WORKSPACE_DIR" ]; then
      echo "Creating workspace directory: $WORKSPACE_DIR"

      if ! mkdir -p "$WORKSPACE_DIR"; then
        echo -e "${RED}Failed to create directory '$WORKSPACE_DIR'. Check permissions.${NC}"
        sleep 2
        WORKSPACE_DIR=""
      fi
    fi
  done

  CHAT_HISTORY_FILE="$WORKSPACE_DIR/chat_history.json"
  EDIT_PERMISSIONS_FILE="$FLOXAGENT_CONFIG_DIR/.floxagent_edit_permissions"
  CREATE_PERMISSIONS_FILE="$FLOXAGENT_CONFIG_DIR/.floxagent_create_permissions"

  : > "$EDIT_PERMISSIONS_FILE"
  : > "$CREATE_PERMISSIONS_FILE"

  SYSTEM_PROMPT='You are FloxAgent, a helpful AI assistant with access to a workspace directory.

You have the following tools available:

READ filename
LIST
EDIT filename
CREATE filename
DELETE filename
BASH command

IMPORTANT RULES:
- When the user asks you to read, view, or check a file, use READ filename
- When asked what files exist, use LIST
- When asked to edit or change a file, first use EDIT filename alone on its own line
- When asked to create a file, first use CREATE filename alone on its own line
- When asked to delete a file, use DELETE filename alone on its own line
- When asked to run a shell command, use BASH command alone on its own line
- DELETE requires user permission and will only happen if the user allows it
- BASH requires user permission and will only run if the user allows it
- Bash commands run inside the workspace directory
- Only after the user allows editing, the tool will give you the current file content
- Only after the user allows creating, you may return the file content
- After edit permission is allowed, return the complete edited file content using exactly:

EDIT filename
---CONTENT---
complete edited file content
---END---

- After create permission is allowed, return the complete file content using exactly:

CREATE filename
---CONTENT---
complete file content
---END---

- Do not use write tools
- Do not invent other tools
- Put tool calls alone on their own line
- After using a tool, wait for the result before providing your answer
- Be helpful and provide short, clear answers

Example:
User: Can you read config.txt?
Assistant:
READ config.txt

Example:
User: Edit config.txt and fix the typo.
Assistant:
EDIT config.txt

Example:
User: Create hello.txt
Assistant:
CREATE hello.txt

Example:
User: Delete old.txt
Assistant:
DELETE old.txt

Example:
User: Run ls
Assistant:
BASH ls'

  echo "$SYSTEM_PROMPT" | jq -Rs '{role: "system", content: .}' | jq -s '.' > "$CHAT_HISTORY_FILE"

  MODEL_OPTIONS=()
  MODEL_DETAILS=()
  CURRENT_MODEL_INDEX=1

  for i in $(seq 0 $((NUM_PROVIDERS - 1))); do
    PROVIDER_NAME=$(echo "$PROVIDERS" | jq -r ".[$i].name")
    API_URL=$(echo "$PROVIDERS" | jq -r ".[$i].api_url")
    API_KEY=$(echo "$PROVIDERS" | jq -r ".[$i].api_key")
    MODELS_STRING=$(echo "$PROVIDERS" | jq -r ".[$i].models")

    OLD_IFS="$IFS"
    IFS=','

    for MODEL_NAME_RAW in $MODELS_STRING; do
      MODEL_NAME=$(echo "$MODEL_NAME_RAW" | xargs)

      if [ -n "$MODEL_NAME" ]; then
        MODEL_OPTIONS+=("[$CURRENT_MODEL_INDEX] $PROVIDER_NAME/$MODEL_NAME")
        MODEL_DETAILS+=("$PROVIDER_NAME|$MODEL_NAME|$API_URL|$API_KEY")
        CURRENT_MODEL_INDEX=$((CURRENT_MODEL_INDEX + 1))
      fi
    done

    IFS="$OLD_IFS"
  done

  if [ "${#MODEL_OPTIONS[@]}" -eq 0 ]; then
    echo -e "${RED}No models found in configured providers. Please check your provider settings.${NC}"
    sleep 2
    clear
    return
  fi

  SELECTED_MODEL_INDEX=""
  SELECTED_PROVIDER_NAME=""
  SELECTED_MODEL_NAME=""
  SELECTED_API_URL=""
  SELECTED_API_KEY=""

  while [ -z "$SELECTED_MODEL_INDEX" ]; do
    clear
    echo "Which Model should be used?"
    echo "--------------------------"

    for option in "${MODEL_OPTIONS[@]}"; do
      echo "$option"
    done

    echo "[0] Back"
    printf "Choice: "
    read -r model_choice

    if [ "$model_choice" = "0" ]; then
      clear
      return
    elif ! [[ "$model_choice" =~ ^[0-9]+$ ]] || [ "$model_choice" -lt 1 ] || [ "$model_choice" -gt "${#MODEL_OPTIONS[@]}" ]; then
      echo -e "${RED}Invalid selection. Please try again.${NC}"
      sleep 1
    else
      SELECTED_MODEL_INDEX=$model_choice
      IFS='|' read -r SELECTED_PROVIDER_NAME SELECTED_MODEL_NAME SELECTED_API_URL SELECTED_API_KEY <<< "${MODEL_DETAILS[$((SELECTED_MODEL_INDEX - 1))]}"
    fi
  done

  clear

  echo "Starting chat with: $SELECTED_PROVIDER_NAME/$SELECTED_MODEL_NAME"
  echo "Workspace: $WORKSPACE_DIR"
  echo "Type '/exit' to end the chat."
  echo "------------------------------------------------------------------"

  set +m

  while :
  do
    printf "\n${GREEN}User:${NC} "
    read -r USER_INPUT

    if [ "$USER_INPUT" = "/exit" ]; then
      echo "Ending chat. Goodbye!"
      sleep 1
      break
    fi

    [ -z "$USER_INPUT" ] && continue

    jq --arg user_input "$USER_INPUT" '. + [{"role": "user", "content": $user_input}]' "$CHAT_HISTORY_FILE" > "$CHAT_HISTORY_FILE.tmp" && mv "$CHAT_HISTORY_FILE.tmp" "$CHAT_HISTORY_FILE"

    MAX_TOOL_ITERATIONS=8
    ITERATION=0

    while [ "$ITERATION" -lt "$MAX_TOOL_ITERATIONS" ]; do
      ITERATION=$((ITERATION + 1))

      show_spinner "Generating..."

      REQUEST_BODY=$(jq -n \
        --arg model "$SELECTED_MODEL_NAME" \
        --slurpfile messages "$CHAT_HISTORY_FILE" \
        '{model: $model, messages: $messages[0], stream: false}')

      RESPONSE_BODY=$(curl -sS -L --fail -X POST "$SELECTED_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $SELECTED_API_KEY" \
        -d "$REQUEST_BODY" 2>&1)

      CURL_STATUS=$?

      hide_spinner

      if [ "$CURL_STATUS" -ne 0 ]; then
        echo -e "\n${RED}Error: API call failed (curl exit status $CURL_STATUS).${NC}" >&2
        echo -e "${RED}Response: $RESPONSE_BODY${NC}" >&2
        sleep 2
        jq 'del(.[-1])' "$CHAT_HISTORY_FILE" > "$CHAT_HISTORY_FILE.tmp" && mv "$CHAT_HISTORY_FILE.tmp" "$CHAT_HISTORY_FILE"
        break
      fi

      if [ -z "$RESPONSE_BODY" ]; then
        echo -e "\n${RED}Error: Empty response from API.${NC}" >&2
        sleep 2
        jq 'del(.[-1])' "$CHAT_HISTORY_FILE" > "$CHAT_HISTORY_FILE.tmp" && mv "$CHAT_HISTORY_FILE.tmp" "$CHAT_HISTORY_FILE"
        break
      fi

      ASSISTANT_RESPONSE=$(echo "$RESPONSE_BODY" | jq -r '.choices[0].message.content // empty' 2>/dev/null)

      if [ -z "$ASSISTANT_RESPONSE" ]; then
        echo -e "\n${RED}Error: Could not get a valid response from the API.${NC}" >&2
        echo -e "${RED}Raw response: $RESPONSE_BODY${NC}" >&2
        sleep 2
        jq 'del(.[-1])' "$CHAT_HISTORY_FILE" > "$CHAT_HISTORY_FILE.tmp" && mv "$CHAT_HISTORY_FILE.tmp" "$CHAT_HISTORY_FILE"
        break
      fi

      jq --arg assistant_response "$ASSISTANT_RESPONSE" '. + [{"role": "assistant", "content": $assistant_response}]' "$CHAT_HISTORY_FILE" > "$CHAT_HISTORY_FILE.tmp" && mv "$CHAT_HISTORY_FILE.tmp" "$CHAT_HISTORY_FILE"

      TOOL_RESULTS=$(process_tool_calls "$ASSISTANT_RESPONSE")

      if [ -n "$TOOL_RESULTS" ]; then
        TOOL_MESSAGE="Tool execution results:$TOOL_RESULTS

Please analyze these results and provide your response to the user."

        jq --arg tool_msg "$TOOL_MESSAGE" '. + [{"role": "user", "content": $tool_msg}]' "$CHAT_HISTORY_FILE" > "$CHAT_HISTORY_FILE.tmp" && mv "$CHAT_HISTORY_FILE.tmp" "$CHAT_HISTORY_FILE"

        continue
      else
        echo -e "${YELLOW}Assistant:${NC} $ASSISTANT_RESPONSE"
        break
      fi
    done
  done

  set -m
  clear
}

clear

echo "Loading..."
apt update

clear

echo "Installing wget, curl, and jq."
apt install curl wget jq -y

clear

while :
do
  echo "FloxAgent V1.0 Menu"
  echo
  echo "[1] Providers"
  echo "[2] Run Agent"
  echo "[0] Exit"
  printf "Choice: "

  read -r choice

  case "$choice" in
    1)
      providers_menu
      ;;

    2)
      run_floxagent
      ;;

    0)
      clear
      break
      ;;

    *)
      clear
      ;;
  esac
done
