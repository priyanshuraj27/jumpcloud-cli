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
  GROUP_ID=$(get_group_id "$GROUP_NAME")
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

# ----------- App Management Functions -------

list_apps() {
  echo "📦 Fetching list of applications..."
  curl -s -X GET \
    -H "x-api-key: $JC_API_KEY" \
    https://console.jumpcloud.com/api/v2/applications | jq
}

get_app_details() {
  read -p "🆔 Enter Application ID: " app_id
  echo "🔍 Fetching application details..."
  curl -s -X GET \
    -H "x-api-key: $JC_API_KEY" \
    https://console.jumpcloud.com/api/v2/applications/$app_id | jq
}

link_app_to_group() {
  read -p "🆔 Enter Application ID: " app_id
  
  read -rp "👥 Enter system group name: " GROUP_NAME

  GROUP_ID=$(get_group_id "$GROUP_NAME")
  if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
    echo "❌ Group not found."
    return
  fi
  echo "🔗 Linking application to group..."
  curl -s -X POST \
    -H "x-api-key: $JC_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"op": "add", "type": "user_group", "id": "'$GROUP_ID'"}' \
    https://console.jumpcloud.com/api/v2/applications/$app_id/associations | jq
}

unlink_app_from_group() {
  read -p "🆔 Enter Application ID: " app_id
  
  read -rp "👥 Enter system group name: " GROUP_NAME

  GROUP_ID=$(get_group_id "$GROUP_NAME")
  if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
    echo "❌ Group not found."
    return
  fi
  echo "❌ Unlinking application from group..."
  curl -s -X POST \
    -H "x-api-key: $JC_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"op": "remove", "type": "user_group", "id": "'$GROUP_ID'"}' \
    https://console.jumpcloud.com/api/v2/applications/$app_id/associations | jq
}
create_import_job() {
  echo "📦 Create Import Job for Application"

  read -p "🔢 Enter Application ID: " application_id
  read -p "🎯 Query string (optional): " query_string
  read -p "🔁 Allow user reactivation? (Y/n): " reactivation_choice

  # Normalize reactivation input
  allow_reactivation=true
  if [[ "$reactivation_choice" =~ ^[Nn]$ ]]; then
    allow_reactivation=false
  fi

  # Use default operations
  operations='["users.create","users.update"]'

  # Fetch org ID (you can cache this to avoid fetching again)
  echo "🔍 Fetching organization ID..."
  org_id=$(curl -s -H "x-api-key: $JC_API_KEY" \
    https://console.jumpcloud.com/api/account | jq -r '.organization')

  if [[ "$org_id" == "null" || -z "$org_id" ]]; then
    echo "❌ Failed to fetch organization ID. Check your API key."
    return 1
  fi

  echo "🚀 Sending import job request..."
  response=$(curl -s -w "\n%{http_code}" -X POST "https://console.jumpcloud.com/api/v2/applications/$application_id/import/jobs" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $JC_API_KEY" \
    -H "x-org-id: $org_id" \
    -d "{
      \"allowUserReactivation\": $allow_reactivation,
      \"operations\": $operations,
      \"queryString\": \"$query_string\"
    }")

  # Split response and HTTP code
  body=$(echo "$response" | head -n -1)
  http_code=$(echo "$response" | tail -n1)

  if [[ "$http_code" == "200" ]]; then
    echo "✅ Import job created successfully!"
  else
    echo "❌ Failed to create import job. HTTP $http_code"
    echo "$body" | jq
  fi
}

uploadAppLogo() {
       read -p "Enter Application ID: " app_id
       read -p "Enter full path to the logo image file: " image_path

       response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://console.jumpcloud.com/api/v2/applications/$app_id/logo" \
          -H "x-api-key: $API_KEY" \
          -F "image=@$image_path")

       if [ "$response" == "204" ]; then
          echo "✅ Logo uploaded successfully."
       else
          echo "❌ Failed to upload logo. HTTP Status: $response"
       fi
}

listAppUserGroups()  {
	read -p "Enter Application ID: " app_id

        curl -s -X GET "https://console.jumpcloud.com/api/v2/applications/$app_id/usergroups" \
          -H "accept: application/json" \
          -H "x-api-key: $JC_API_KEY" | jq
}

listAppUsers() {
	 read -p "Enter Application ID: " app_id

         curl -s -X GET "https://console.jumpcloud.com/api/v2/applications/$app_id/users" \
           -H "accept: application/json" \
           -H "x-api-key: $JC_API_KEY" | jq
}

# ----------------- Menus --------------------

user_management(){
  while true; do
    echo
    echo "====== User Management ======"
    echo "1. Add user to group"
    echo "2. Remove user from group"
    echo "3. List all users"
    echo "4. List all groups"
    echo "5. Return to main menu"
    echo "============================="
    read -rp "Choose an option [1-5]: " choice
    case "$choice" in 
      1) add_user_to_group ;;
      2) remove_user_from_group ;;
      3) list_all_users ;;
      4) list_all_groups ;;
      5) return;;
      *) echo "⚠️ Invalid option. Try again." ;;
    esac
  done
}


systems_management(){
  while true; do
    echo
    echo "====== System Management ======"
    echo "1. View system info"
    echo "2. List all systems"
    echo "3. View users on system"
    echo "4. View system’s group memberships"
    echo "5. Add system to system group"
    echo "6. Delete a system"
    echo "7. Return to main menu"
    echo "================================"
    read -rp "Choose an option [1-7]: " choice
    case "$choice" in 
      1) view_system_info;;
      2) list_all_systems;;
      3) view_users_on_system;;
      4) view_system_groups;;
      5) add_system_to_group;;
      6) delete_system;;
      7) return;;
      *) echo "⚠️ Invalid option. Try again." ;;
    esac
  done
}

app_management(){
  while true; do
    echo
    echo "====== App Management ======="
    echo "1. List all applications"
    echo "2. Get application details"
    echo "3. Link app to user group"
    echo "4. Unlink app from user group"
    echo "5. Create Import User Job for Application."
    echo "6. Set or Update Application Logo"
    echo "7. List all user groups bound to Application"
    echo "8. List all users bound to Application"
    echo "9. Return to main menu"
    echo "============================="
    read -rp "Choose an option [1-9]: " choice
    case "$choice" in 
      1) list_apps ;;
      2) get_app_details ;;
      3) link_app_to_group ;;
      4) unlink_app_from_group ;;
      5) create_import_job;;
      6) uploadAppLogo;;
      7) listAppUserGroups;;
      8) listAppUsers;; 
      9) return;;
      *) echo "⚠️ Invalid option. Try again." ;;
    esac
  done
}

# ----------------- 📋 Main Menu -----------------
main_menu() {
  while true; do
    echo
    echo "====== JumpCloud CLI Menu ======"
    echo "1. Set/ Update API key"
    echo "2  User Management"
    echo "3. Systems Management"
    echo "4. App Management"
    echo "5. Exit"
    echo "================================"
    read -rp "Choose an option [1-5]: " choice

    case "$choice" in
      1) set_api_key;;
      2) user_management;;
      3) systems_management;;
      4) app_management;;
      5) echo "👋 Goodbye!"; exit 0 ;;
      *) echo "⚠️ Invalid option. Try again." ;;
    esac
  done
}

# ----------------- 🚀 Entry Point -----------------

load_api_key
main_menu
