#!/bin/bash

VERSION="v1.3.0"

show_help() {
    cat <<EOF
Usage: cloudgate <command> [options]

Commands:
  saml          Login to AWS via SAML (saml2aws)
  eks-allowip   Whitelist your current IP on EKS cluster publicAccessCidrs

Options:
  --help             Display this help message
  --version          Display version information
  --show-commands    Show available commands

Run 'cloudgate <command> --help' for command-specific help.
EOF
}

show_commands() {
    cat <<EOF
cloudgate available commands:

  cloudgate saml                  AWS SAML login (saml2aws)
  cloudgate saml config           Configure AWS profiles for SAML
  cloudgate saml --help           Show saml command help
  cloudgate saml --version        Show saml version

  cloudgate eks-allowip           Whitelist your IP on EKS clusters
  cloudgate eks-allowip --help    Show eks-allowip command help
  cloudgate eks-allowip --version Show eks-allowip version

  cloudgate --help                Display this help message
  cloudgate --version             Display version information
  cloudgate --show-commands       Show this command list

EOF
}

check_dep() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" > /dev/null 2>&1; then
        echo "Error: '$cmd' is not installed or not in PATH."
        echo "  $hint"
        exit 1
    fi
}

case "$1" in
    saml)
        check_dep aws    "Install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        check_dep saml2aws "Install saml2aws: https://github.com/Versent/saml2aws#installation"
        shift
        aws-login "$@"
        ;;
    eks-allowip)
        check_dep aws  "Install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        check_dep jq   "Install jq: https://stedolan.github.io/jq/download/"
        check_dep dig  "Install bind-tools (Linux) or use macOS which includes dig by default."
        shift
        eks-allowip "$@"
        ;;
    --version)
        echo "cloudgate $VERSION"
        ;;
    --help)
        show_help
        ;;
    --show-commands)
        show_commands
        ;;
    "")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
