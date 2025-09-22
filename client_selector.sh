#!/bin/bash

# Ethereum Client Selection and Installation Script
# This script helps users choose and install Ethereum clients

source ./exports.sh
source ./common_functions.sh

# Colors for menu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Menu functions
show_header() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    Ethereum Client Installation Tool    ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo
}

show_execution_clients() {
    echo -e "${BLUE}Execution Clients (Choose 1):${NC}"
    echo "1. Geth (Go-Ethereum) - Most popular, battle-tested"
    echo "2. Nethermind - High performance, .NET based"
    echo "3. Besu - Enterprise-focused, Java based"
    echo "4. Erigon - Fast sync, Go based"
    echo "5. Reth - Rust based, high performance"
    echo "6. Skip execution client"
    echo
}

show_consensus_clients() {
    echo -e "${BLUE}Consensus Clients (Choose 1):${NC}"
    echo "1. Prysm - Most popular, Go based"
    echo "2. Lighthouse - High performance, Rust based"
    echo "3. Teku - Enterprise-focused, Java based"
    echo "4. Nimbus - Lightweight, Nim based"
    echo "5. Lodestar - TypeScript based"
    echo "6. Skip consensus client"
    echo
}

show_validator_clients() {
    echo -e "${BLUE}Validator Clients (Choose 1):${NC}"
    echo "1. Prysm Validator - Integrated with Prysm"
    echo "2. Lighthouse Validator - Integrated with Lighthouse"
    echo "3. Teku Validator - Integrated with Teku"
    echo "4. Nimbus Validator - Integrated with Nimbus"
    echo "5. Lodestar Validator - Integrated with Lodestar"
    echo "6. Skip validator client"
    echo
}

get_user_choice() {
    local prompt="$1"
    local max_choice="$2"
    local choice
    
    while true; do
        echo -n -e "${YELLOW}$prompt${NC} "
        read choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_choice" ]; then
            echo "$choice"
            return
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and $max_choice.${NC}"
        fi
    done
}

install_execution_client() {
    local choice="$1"
    
    case "$choice" in
        1)
            log_info "Installing Geth..."
            ./install_geth.sh
            ;;
        2)
            log_info "Installing Nethermind..."
            ./install_nethermind.sh
            ;;
        3)
            log_info "Installing Besu..."
            ./install_besu.sh
            ;;
        4)
            log_info "Installing Erigon..."
            ./erigon.sh
            ;;
        5)
            log_info "Installing Reth..."
            ./install_reth.sh
            ;;
        6)
            log_info "Skipping execution client installation"
            ;;
    esac
}

install_consensus_client() {
    local choice="$1"
    
    case "$choice" in
        1)
            log_info "Installing Prysm..."
            ./install_prysm.sh
            ;;
        2)
            log_info "Installing Lighthouse..."
            ./lighthouse.sh
            ;;
        3)
            log_info "Installing Teku..."
            ./install_teku.sh
            ;;
        4)
            log_info "Installing Nimbus..."
            ./install_nimbus.sh
            ;;
        5)
            log_info "Installing Lodestar..."
            ./install_lodestar.sh
            ;;
        6)
            log_info "Skipping consensus client installation"
            ;;
    esac
}

install_validator_client() {
    local choice="$1"
    
    case "$choice" in
        1)
            log_info "Installing Prysm Validator..."
            # Prysm validator is installed with the consensus client
            log_info "Prysm validator is already installed with the consensus client"
            ;;
        2)
            log_info "Installing Lighthouse Validator..."
            # Lighthouse validator is integrated with the consensus client
            log_info "Lighthouse validator is integrated with the consensus client"
            ;;
        3)
            log_info "Installing Teku Validator..."
            ./install_teku_validator.sh
            ;;
        4)
            log_info "Installing Nimbus Validator..."
            # Nimbus validator is integrated with the consensus client
            log_info "Nimbus validator is integrated with the consensus client"
            ;;
        5)
            log_info "Installing Lodestar Validator..."
            # Lodestar validator is integrated with the consensus client
            log_info "Lodestar validator is integrated with the consensus client"
            ;;
        6)
            log_info "Skipping validator client installation"
            ;;
    esac
}

show_installation_summary() {
    local execution_choice="$1"
    local consensus_choice="$2"
    local validator_choice="$3"
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}        Installation Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    echo -e "${BLUE}Selected Clients:${NC}"
    
    case "$execution_choice" in
        1) echo "  • Execution: Geth" ;;
        2) echo "  • Execution: Nethermind" ;;
        3) echo "  • Execution: Besu" ;;
        4) echo "  • Execution: Erigon" ;;
        5) echo "  • Execution: Reth" ;;
        6) echo "  • Execution: None" ;;
    esac
    
    case "$consensus_choice" in
        1) echo "  • Consensus: Prysm" ;;
        2) echo "  • Consensus: Lighthouse" ;;
        3) echo "  • Consensus: Teku" ;;
        4) echo "  • Consensus: Nimbus" ;;
        5) echo "  • Consensus: Lodestar" ;;
        6) echo "  • Consensus: None" ;;
    esac
    
    case "$validator_choice" in
        1) echo "  • Validator: Prysm" ;;
        2) echo "  • Validator: Lighthouse" ;;
        3) echo "  • Validator: Teku" ;;
        4) echo "  • Validator: Nimbus" ;;
        5) echo "  • Validator: Lodestar" ;;
        6) echo "  • Validator: None" ;;
    esac
    
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Configure your clients in exports.sh"
    echo "2. Start your services with systemctl"
    echo "3. Monitor logs and sync status"
    echo "4. Set up your validator keys (if running a validator)"
    echo
}

# Main installation flow
main() {
    show_header
    
    echo -e "${PURPLE}Welcome to the Ethereum Client Installation Tool!${NC}"
    echo "This tool will help you install Ethereum execution and consensus clients."
    echo
    echo -e "${YELLOW}Note: You should install one execution client and one consensus client.${NC}"
    echo -e "${YELLOW}If you plan to run a validator, you'll also need a validator client.${NC}"
    echo
    
    # Get user choices
    show_execution_clients
    execution_choice=$(get_user_choice "Choose execution client (1-6):" 6)
    
    show_consensus_clients
    consensus_choice=$(get_user_choice "Choose consensus client (1-6):" 6)
    
    show_validator_clients
    validator_choice=$(get_user_choice "Choose validator client (1-6):" 6)
    
    # Show summary and confirm
    show_installation_summary "$execution_choice" "$consensus_choice" "$validator_choice"
    
    echo -n -e "${YELLOW}Proceed with installation? (y/N): ${NC}"
    read confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo
        log_info "Starting installation process..."
        
        # Install clients
        install_execution_client "$execution_choice"
        install_consensus_client "$consensus_choice"
        install_validator_client "$validator_choice"
        
        echo
        log_success "Installation completed!"
        echo
        echo -e "${GREEN}Your Ethereum clients have been installed and configured.${NC}"
        echo -e "${GREEN}Check the individual installation logs above for any issues.${NC}"
        echo
        echo -e "${YELLOW}To start your services:${NC}"
        echo "  sudo systemctl start eth1    # Start execution client"
        echo "  sudo systemctl start cl      # Start consensus client"
        echo "  sudo systemctl start validator # Start validator client (if installed)"
        echo
        echo -e "${YELLOW}To check status:${NC}"
        echo "  sudo systemctl status eth1"
        echo "  sudo systemctl status cl"
        echo "  sudo systemctl status validator"
        
    else
        echo
        log_info "Installation cancelled."
        exit 0
    fi
}

# Run main function
main