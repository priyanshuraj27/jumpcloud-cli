#!/bin/bash
#Reach out to https://github.com/bhuvangoel04 for any suggestions, issues or if you need support.
CONFIG_FILE="$HOME/.jc-cli"

# ----------------- 🔐 Load / Save API Key -----------------

load_api_key() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
  fi

  if [[ -z "$JC_API_KEY" ]]; then
    echo -n "🔑 Enter your JumpCloud API key: "
    read -rs JC_API_KEY
    echo
    echo "JC_API_KEY=$JC_API_KEY" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo "✅ API key saved to $CONFIG_FILE"
  fi
}

set_api_key() {
  echo -n "🔑 Enter new JumpCloud API key: "
  read -rs JC_API_KEY
  echo
  echo "JC_API_KEY=$JC_API_KEY" > "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
  echo "✅ New API key saved."
}

# ----------------- 🔧 Helper Functions -----------------

get_user_id() {
  local email="$1"
  curl -s -X GET "https://console.jumpcloud.com/api/systemusers?filter=email:\$eq:$email" \
    -H "x-api-key: $JC_API_KEY" | jq -r '.results[] | .id'
}

get_group_id() {
  local group_name="$1"
  curl -s -X GET "https://console.jumpcloud.com/api/v2/usergroups?limit=100" \
    -H "x-api-key: $JC_API_KEY" | jq -r --arg name "$group_name" '.[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id'
}

# ----------------- 🚀 Operations -----------------

add_user_to_group() {
  read -rp "📧 Enter user email: " USER_EMAIL
  USER_ID=$(get_user_id "$USER_EMAIL")

  if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
    echo "❌ User not found."
    return
  fi

  read -rp "👥 Enter group name: " GROUP_NAME
  GROUP_ID=$(get_group_id "$GROUP_NAME")

  if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
    echo "❌ Group not found."
    return
  fi
  MEMBERS=$(curl -s -X GET "https://console.jumpcloud.com/api/v2/usergroups/$GROUP_ID/members" \
    -H "x-api-key: $JC_API_KEY")

  if echo "$MEMBERS" | jq -e --arg uid "$USER_ID" '.[] | select(.to.id == $uid)' > /dev/null; then
    echo "ℹ️ User is already a member of the group."
    return
  fi
  echo "🚀 Adding user to group..."
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://console.jumpcloud.com/api/v2/usergroups/$GROUP_ID/members" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $JC_API_KEY" \
    -d "{\"op\": \"add\", \"type\": \"user\", \"id\": \"$USER_ID\"}")

  if [[ "$RESPONSE" == "204" ]]; then
    echo "✅ User added successfully."
  else
    echo "❌ Failed. HTTP code: $RESPONSE"
  fi
}

remove_user_from_group() {
  read -rp "📧 Enter user email: " USER_EMAIL
  USER_ID=$(get_user_id "$USER_EMAIL")

  if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
    echo "❌ User not found."
    return
  fi

  read -rp "👥 Enter group name: " GROUP_NAME
  GROUP_ID=$(get_group_id "$GROUP_NAME")

  if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
    echo "❌ Group not found."
    return
  fi

  echo "🧹 Removing user from group..."
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://console.jumpcloud.com/api/v2/usergroups/$GROUP_ID/members" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $JC_API_KEY" \
    -d "{\"op\": \"remove\", \"type\": \"user\", \"id\": \"$USER_ID\"}")

  if [[ "$RESPONSE" == "204" ]]; then
    echo "✅ User removed successfully."
  else
    echo "❌ Failed. HTTP code: $RESPONSE"
  fi
}

list_all_users() {
  echo "📋 Listing all users:"
  curl -s -X GET "https://console.jumpcloud.com/api/systemusers?limit=100" \
    -H "x-api-key: $JC_API_KEY" | jq -r '.results[] | "\(.email) (\(.username))"'
}

list_all_groups() {
  echo "📋 Listing all user groups:"
  curl -s -X GET "https://console.jumpcloud.com/api/v2/usergroups" \
    -H "x-api-key: $JC_API_KEY" | jq -r '.[] | "\(.name) [\(.id)]"'
}

# ===================== SYSTEM FUNCTIONS ======================

get_system_id_by_hostname() {
  local hostname="$1"
  curl -s -X GET "https://console.jumpcloud.com/api/systems?filter=hostname:\$eq:$hostname" \
    -H "x-api-key: $JC_API_KEY" | jq -r '.results[0].id'
}

view_system_info() {
  read -rp "💻 Enter system hostname: " HOSTNAME
  SYSTEM_ID=$(get_system_id_by_hostname "$HOSTNAME")

  if [[ -z "$SYSTEM_ID" || "$SYSTEM_ID" == "null" ]]; then
    echo "❌ System not found."
    return
  fi

  echo "🔍 System Info for '$HOSTNAME':"
  curl -s -X GET "https://console.jumpcloud.com/api/systems/$SYSTEM_ID" \
    -H "x-api-key: $JC_API_KEY" | jq
}

list_all_systems() {
  echo "🖥️ Listing all systems:"
  curl -s -X GET "https://console.jumpcloud.com/api/systems?limit=100" \
    -H "x-api-key: $JC_API_KEY" | jq -r '.results[] | "\(.hostname)\t|\t\(.os)\t|\t\(.id)\t|\tActive: \(.allowPublicKeyAuthentication)"' | column -t -s $'\t'
}

view_users_on_system() {
  read -rp "💻 Enter system hostname: " HOSTNAME
  SYSTEM_ID=$(get_system_id_by_hostname "$HOSTNAME")

  if [[ -z "$SYSTEM_ID" || "$SYSTEM_ID" == "null" ]]; then
    echo "❌ System not found."
    return
  fi

  echo "👤 Users bound to system '$HOSTNAME':"
  curl -s -X GET "https://console.jumpcloud.com/api/v2/systems/$SYSTEM_ID/users" \
    -H "x-api-key: $JC_API_KEY" | jq -r '.[] | "\(.attributes.email) (\(.id))"'
}

view_system_groups() {
  read -rp "💻 Enter system hostname: " HOSTNAME
  SYSTEM_ID=$(get_system_id_by_hostname "$HOSTNAME")

  if [[ -z "$SYSTEM_ID" || "$SYSTEM_ID" == "null" ]]; then
    echo "❌ System not found."
    return
  fi

  echo "🧠 Groups for system '$HOSTNAME':"
  curl -s -X GET "https://console.jumpcloud.com/api/v2/systems/$SYSTEM_ID/memberof" \
    -H "x-api-key: $JC_API_KEY" | jq -r '.[] | select(.type=="system_group") | .name'
}

add_system_to_group() {
  read -rp "💻 Enter system hostname: " HOSTNAME
  SYSTEM_ID=$(get_system_id_by_hostname "$HOSTNAME")

  if [[ -z "$SYSTEM_ID" || "$SYSTEM_ID" == "null" ]]; then
    echo "❌ System not found."
    return
  fi

  read -rp "👥 Enter system group name: " GROUP_NAME

  GROUP_ID=$(curl -s -X GET "https://console.jumpcloud.com/api/v2/systemgroups?filter=name:eq:$GROUP_NAME" \
    -H "x-api-key: $JC_API_KEY" | jq -r '.[0].id')

  if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
    echo "❌ Group not found."
    return
  fi

  # Check membership before adding
  CURRENT_MEMBERS=$(curl -s -X GET "https://console.jumpcloud.com/api/v2/systemgroups/$GROUP_ID/members" \
    -H "x-api-key: $JC_API_KEY")

  if echo "$CURRENT_MEMBERS" | jq -e --arg sid "$SYSTEM_ID" '.[] | select(.to.id == $sid)' > /dev/null; then
    echo "ℹ️ System already in group."
    return
  fi

  echo "🚀 Adding system to group..."
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://console.jumpcloud.com/api/v2/systemgroups/$GROUP_ID/members" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $JC_API_KEY" \
    -d "{\"op\": \"add\", \"type\": \"system\", \"id\": \"$SYSTEM_ID\"}")

  if [[ "$RESPONSE" == "204" ]]; then
    echo "✅ System added to group."
  else
    echo "❌ Failed. HTTP code: $RESPONSE"
  fi
}

delete_system() {
  read -rp "💻 Enter system hostname: " HOSTNAME
  SYSTEM_ID=$(get_system_id_by_hostname "$HOSTNAME")

  if [[ -z "$SYSTEM_ID" || "$SYSTEM_ID" == "null" ]]; then
    echo "❌ System not found."
    return
  fi

  read -rp "⚠️ Are you sure you want to DELETE this system? Type 'yes' to confirm: " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "❌ Cancelled."
    return
  fi

  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "https://console.jumpcloud.com/api/systems/$SYSTEM_ID" \
    -H "x-api-key: $JC_API_KEY")

  if [[ "$RESPONSE" == "204" ]]; then
    echo "🗑️ System deleted successfully."
  else
    echo "❌ Deletion failed. HTTP code: $RESPONSE"
  fi
}


# ----------------- 📋 Main Menu -----------------

main_menu() {
  while true; do
    echo
    echo "====== JumpCloud CLI Menu ======"
    echo "1. Add user to group"
    echo "2. Remove user from group"
    echo "3. List all users"
    echo "4. List all groups"
    echo "5. Set / Update API key"
    echo "6. Exit"
    echo "====== System Management ======"
    echo "7. View system info"
    echo "8. List all systems"
    echo "9. View users on system"
    echo "10. View system’s group memberships"
    echo "11. Add system to system group"
    echo "12. Delete a system"
    echo "================================"
    read -rp "Choose an option [1-12]: " choice

    case "$choice" in
      1) add_user_to_group ;;
      2) remove_user_from_group ;;
      3) list_all_users ;;
      4) list_all_groups ;;
      5) set_api_key ;;
      6) echo "👋 Goodbye!"; exit 0 ;;
      7) view_system_info ;;
      8) list_all_systems ;;
      9) view_users_on_system ;;
      10) view_system_groups ;;
      11) add_system_to_group ;;
      12) delete_system ;;
      *) echo "⚠️ Invalid option. Try again." ;;
    esac
  done
}

# ----------------- 🚀 Entry Point -----------------

load_api_key
main_menu
