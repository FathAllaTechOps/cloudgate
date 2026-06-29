#!/bin/bash

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/usr/local/bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}cloudgate installer${RESET}"
echo -e "${DIM}Installing from: $REPO_DIR${RESET}"
echo ""

# Check dependencies
check_dep() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" > /dev/null 2>&1; then
        echo -e "${RED}✗ Missing dependency: '$cmd'${RESET}"
        echo -e "  $hint"
        exit 1
    fi
}

check_dep aws      "Install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
check_dep saml2aws "Install saml2aws: https://github.com/Versent/saml2aws#installation"
check_dep jq       "Install jq: brew install jq / apt-get install jq"
check_dep dig      "Install dig: brew install bind / apt-get install dnsutils"

# Determine install directory
if [ -w "$INSTALL_DIR" ]; then
    USE_SUDO=""
else
    USE_SUDO="sudo"
fi

echo -e "${BOLD}Installing binaries to $INSTALL_DIR${RESET}"

$USE_SUDO cp "$REPO_DIR/bin/cloudgate.sh"      "$INSTALL_DIR/cloudgate"
$USE_SUDO cp "$REPO_DIR/bin/cloudgate-saml.sh" "$INSTALL_DIR/cloudgate-saml"
$USE_SUDO cp "$REPO_DIR/bin/eks-allowip.sh"    "$INSTALL_DIR/eks-allowip"

$USE_SUDO chmod +x "$INSTALL_DIR/cloudgate"
$USE_SUDO chmod +x "$INSTALL_DIR/cloudgate-saml"
$USE_SUDO chmod +x "$INSTALL_DIR/eks-allowip"

echo ""
echo -e "  ${GREEN}✓${RESET} cloudgate"
echo -e "  ${GREEN}✓${RESET} cloudgate-saml"
echo -e "  ${GREEN}✓${RESET} eks-allowip"
echo ""

# Verify
if ! command -v cloudgate > /dev/null 2>&1; then
    echo -e "${RED}✗ Installation failed — '$INSTALL_DIR' is not in your PATH.${RESET}"
    echo -e "  Add this to your shell profile:"
    echo -e "  export PATH=\"\$PATH:$INSTALL_DIR\""
    exit 1
fi

VERSION=$(cloudgate --version)
echo -e "${GREEN}✓ $VERSION installed successfully.${RESET}"
echo ""
echo -e "${BOLD}Getting started:${RESET}"
echo -e "  cloudgate saml              ${DIM}# login to AWS${RESET}"
echo -e "  cloudgate eks-allowip       ${DIM}# whitelist your IP on EKS clusters${RESET}"
echo -e "  cloudgate status            ${DIM}# check session status${RESET}"
echo -e "  cloudgate saml config --list ${DIM}# view configured profiles${RESET}"
echo ""
