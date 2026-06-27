#!/bin/bash

CONFIG_DIR="$HOME/.cloudgate"
CONFIG_FILE="$CONFIG_DIR/profiles.config"
CLOUDGATE_CONFIG="$CONFIG_DIR/config"
VERSION="v2.6.0"

load_profiles() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    else
        profiles=()
    fi
}

save_profiles() {
    mkdir -p "$CONFIG_DIR"
    echo "profiles=(" > "$CONFIG_FILE"
    for profile in "${profiles[@]}"; do
        echo "    \"$profile\"" >> "$CONFIG_FILE"
    done
    echo ")" >> "$CONFIG_FILE"
}

list_profiles() {
    load_profiles
    if [ ${#profiles[@]} -eq 0 ]; then
        echo "No profiles configured. Run 'cloudgate saml config' to add profiles."
        return
    fi
    echo "Configured AWS profiles:"
    for profile in "${profiles[@]}"; do
        echo "  - $profile"
    done
}

config_profiles() {
    echo "Enter the AWS profiles (one per line). Enter an empty line to finish:"
    profiles=()
    while :; do
        read -r -p "Profile: " profile
        [ -z "$profile" ] && break
        profiles+=("$profile")
    done
    save_profiles
    echo "Profiles saved to $CONFIG_FILE"
}

load_email() {
    [ -n "$SAML_EMAIL" ] && return
    if [ -f "$CLOUDGATE_CONFIG" ]; then
        local saml_email=""
        # shellcheck source=/dev/null
        source "$CLOUDGATE_CONFIG"
        [ -n "$saml_email" ] && SAML_EMAIL="$saml_email"
    fi
}

save_email() {
    mkdir -p "$CONFIG_DIR"
    if [ -f "$CLOUDGATE_CONFIG" ] && grep -q '^saml_email=' "$CLOUDGATE_CONFIG"; then
        sed -i '' "s|^saml_email=.*|saml_email=\"$1\"|" "$CLOUDGATE_CONFIG"
    else
        echo "saml_email=\"$1\"" >> "$CLOUDGATE_CONFIG"
    fi
}

display_help() {
    cat <<EOF
Usage: cloudgate saml [OPTION]

Options:
  config                Configure the AWS profiles for SAML authentication.
  config --list         List configured AWS profiles.
  --help                Display this help message and exit.
  --version             Display version information and exit.
  --show-commands       Show available commands and exit.
  --forget-password     Remove saved password from keychain.

Description:
  Authenticates to multiple AWS accounts using SAML (saml2aws) and updates
  kubeconfig for all EKS clusters in eu-west-1 and eu-central-1.

  Your password can be saved securely in the system keychain (macOS Keychain
  or Linux secret-tool) so you don't need to type it every time.

  After login, optionally runs 'cloudgate eks-allowip' to whitelist your IP.

Example:
  cloudgate saml config            # first-time setup
  cloudgate saml                   # authenticate and update kubeconfigs
  cloudgate saml --forget-password # clear saved password from keychain

EOF
}

display_version() {
    echo "cloudgate saml $VERSION"
}

display_commands() {
    cat <<EOF
cloudgate available commands:

  cloudgate saml                      AWS SAML login (saml2aws)
  cloudgate saml config               Configure AWS profiles
  cloudgate saml --forget-password    Remove saved password from keychain
  cloudgate saml --help               Show help
  cloudgate saml --version            Show version
  cloudgate saml --show-commands      Show this command list

  cloudgate eks-allowip           Whitelist your IP on EKS clusters
  cloudgate --show-commands       Show all cloudgate commands

EOF
}

KEYCHAIN_SERVICE="cloudgate-saml"

keychain_get() {
    if command -v security > /dev/null 2>&1; then
        security find-generic-password -a "$1" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null
    elif command -v secret-tool > /dev/null 2>&1; then
        secret-tool lookup service "$KEYCHAIN_SERVICE" account "$1" 2>/dev/null
    fi
}

keychain_set() {
    if command -v security > /dev/null 2>&1; then
        security add-generic-password -a "$1" -s "$KEYCHAIN_SERVICE" -w "$2" -U 2>/dev/null
    elif command -v secret-tool > /dev/null 2>&1; then
        printf '%s' "$2" | secret-tool store --label="cloudgate SAML password" service "$KEYCHAIN_SERVICE" account "$1" 2>/dev/null
    fi
}

keychain_delete() {
    if command -v security > /dev/null 2>&1; then
        security delete-generic-password -a "$1" -s "$KEYCHAIN_SERVICE" 2>/dev/null
    elif command -v secret-tool > /dev/null 2>&1; then
        secret-tool clear service "$KEYCHAIN_SERVICE" account "$1" 2>/dev/null
    fi
}

read_password() {
    prompt=$1
    password=""
    while IFS= read -r -p "$prompt" -s -n 1 char; do
        if [[ $char == $'\0' ]]; then
            break
        fi
        prompt='*'
        password+="$char"
    done
    echo
}

if [ "$1" == "--help" ]; then
    display_help
    exit 0
fi

if [ "$1" == "--version" ]; then
    display_version
    exit 0
fi

if [ "$1" == "--show-commands" ]; then
    display_commands
    exit 0
fi

if [ "$1" == "--forget-password" ]; then
    if [ -z "$SAML_EMAIL" ]; then
        read -r -p "Enter the email to forget password for: " SAML_EMAIL
    fi
    keychain_delete "$SAML_EMAIL"
    echo -e "${GREEN}✓ Password removed from keychain for $SAML_EMAIL${RESET}"
    exit 0
fi

if [ "$1" == "config" ]; then
    if [ "$2" == "--list" ]; then
        list_profiles
    else
        config_profiles
    fi
    exit 0
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

load_profiles

if [ ${#profiles[@]} -eq 0 ]; then
    echo -e "${RED}✗ No profiles found. Please run 'cloudgate saml config' to configure profiles.${RESET}"
    exit 1
fi

load_email
if [ -z "$SAML_EMAIL" ]; then
    read -r -p "Enter the email: " SAML_EMAIL
    export SAML_EMAIL
    read -r -p "Save email for next time? (yes/no): " save_em
    if [ "$save_em" == "yes" ]; then
        save_email "$SAML_EMAIL"
        echo -e "${GREEN}✓ Email saved to ~/.cloudgate/config${RESET}"
    fi
else
    echo -e "${DIM}Using email: $SAML_EMAIL${RESET}"
fi

password=$(keychain_get "$SAML_EMAIL")
if [ -n "$password" ]; then
    echo -e "${GREEN}🔑 Using saved password from keychain.${RESET} ${DIM}(run 'cloudgate saml --forget-password' to clear)${RESET}"
else
    read_password "Enter the password: "
    read -r -p "Save password to keychain for next time? (yes/no): " save_pw
    if [ "$save_pw" == "yes" ]; then
        keychain_set "$SAML_EMAIL" "$password"
        echo -e "${GREEN}✓ Password saved to keychain.${RESET}"
    fi
fi

echo ""
echo -e "${BOLD}Available AWS Accounts:${RESET}"
i=1
for profile in "${profiles[@]}"; do
    echo -e "  ${CYAN}$i)${RESET} ${BOLD}$profile${RESET}"
    ((i++))
done
echo ""

read -r -p "Enter the numbers of the profiles you want to use, separated by commas (e.g., 1,3,5): " selected_profiles

IFS=',' read -ra profile_indices <<< "$selected_profiles"

failed_profiles=()

login_with_profile() {
    local profile=$1
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "🔐 ${BOLD}Logging in with profile: ${CYAN}$profile${RESET}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    sed -i '' '/aws_profile/d' ~/.saml2aws
    echo "aws_profile             = $profile" >> ~/.saml2aws

    if saml2aws login --force --username="$SAML_EMAIL" --password="$password" --skip-prompt --session-duration 43200; then
        echo -e "  ${GREEN}✓ Login successful for ${BOLD}$profile${RESET}"
        return 0
    else
        echo -e "  ${RED}✗ Login failed for ${BOLD}$profile${RESET}"
        failed_profiles+=("$profile")
        return 1
    fi
}

succeeded_indices=()
for index in "${profile_indices[@]}"; do
    profile=${profiles[$((index-1))]}
    if [ -n "$profile" ]; then
        if login_with_profile "$profile"; then
            succeeded_indices+=("$index")
        fi
    else
        echo -e "${RED}✗ Invalid profile selection: $index. Skipping.${RESET}"
    fi
done

echo ""
if [ ${#failed_profiles[@]} -gt 0 ]; then
    echo -e "${RED}✗ Login failed for: ${failed_profiles[*]}${RESET}"
    echo -e "${DIM}  Try 'cloudgate saml --forget-password' if your password has changed.${RESET}"
fi
if [ ${#succeeded_indices[@]} -eq 0 ]; then
    echo -e "${RED}✗ No profiles logged in successfully. Exiting.${RESET}"
    exit 1
fi
echo -e "${GREEN}✓ Completed login for all selected profiles.${RESET}"
unset password

regions=(
    "eu-west-1"
    "eu-central-1"
)

echo ""
echo -e "${BOLD}Updating kubeconfigs...${RESET}"
for region in "${regions[@]}"; do
    for index in "${succeeded_indices[@]}"; do
        profile=${profiles[$((index-1))]}
        if [ -n "$profile" ]; then
            clusters=$(aws eks list-clusters --output text --profile "$profile" --region "$region" 2>/dev/null | awk '{print $2}')
            while read -r cluster; do
                [ -z "$cluster" ] && continue
                if aws eks update-kubeconfig --region "$region" --name "$cluster" --profile "$profile" > /dev/null 2>&1; then
                    echo -e "  ${GREEN}✓${RESET} ${BOLD}$cluster${RESET} ${DIM}($region ← $profile)${RESET}"
                else
                    echo -e "  ${RED}✗${RESET} Failed to update kubeconfig for ${BOLD}$cluster${RESET} ${DIM}($region ← $profile)${RESET}"
                fi
            done <<< "$clusters"
        fi
    done
done

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  💡 ${DIM}All clusters (lower and higher) are restricted to${RESET}"
echo -e "  ${DIM}Vodafone VPN. Whitelist your IP to access them.${RESET}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

read -r -p "Do you want to whitelist your IP on EKS clusters? (yes/no): " proceed

if [ "$proceed" == "yes" ]; then
    cloudgate eks-allowip
else
    echo -e "${DIM}Whitelisting skipped.${RESET}"
fi
