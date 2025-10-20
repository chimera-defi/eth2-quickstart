#!/bin/bash

# Ethereum Client Installation Script
# This script provides quick installation options for different client combinations

source ../../lib/common_functions.sh

# Colors for better readability
BOLD='\033[1m'
UNDERLINE='\033[4m'

display_header() {
    echo -e "${BOLD}${GREEN}"
    echo "=============================================="
    echo "    Ethereum Client Installation Assistant"
    echo "=============================================="
    echo -e "${NC}"
}

show_installation_options() {
    echo -e "${BOLD}${UNDERLINE}INSTALLATION OPTIONS${NC}"
    echo
    echo "1. Default Setup (Geth + Prysm + MEV Boost) - Recommended for beginners"
    echo "2. Performance Setup (Erigon + Lighthouse + MEV Boost) - Faster sync"
    echo "3. Lightweight Setup (Geth + Nimbus + MEV Boost) - Low resource usage"
    echo "4. Enterprise Setup (Nethermind + Teku + MEV Boost) - Advanced features"
    echo "5. Custom Setup - Choose individual clients"
    echo "6. View Client Information"
    echo "7. Exit"
    echo
}

install_default_setup() {
    log_info "Installing default setup (Geth + Prysm + MEV Boost)..."
    
    # Stop any existing services
    sudo systemctl stop eth1 cl validator mev 2>/dev/null || true
    
    log_info "Installing Geth execution client..."
    if ! ./install/execution/install_geth.sh; then
        log_error "Failed to install Geth"
        return 1
    fi

    log_info "Installing Prysm consensus client..."
    if ! ./install/consensus/install_prysm.sh; then
        log_error "Failed to install Prysm"
        return 1
    fi

    log_info "Installing MEV Boost..."
    if ! ./install/mev/install_mev_boost.sh; then
        log_error "Failed to install MEV Boost"
        return 1
    fi

    log_info "Default setup completed successfully!"
    return 0
}

install_performance_setup() {
    log_info "Installing performance setup (Erigon + Lighthouse + MEV Boost)..."
    
    # Stop any existing services
    sudo systemctl stop eth1 cl validator mev 2>/dev/null || true
    
    log_info "Installing Erigon execution client..."
    if ! ./install/execution/erigon.sh; then
        log_error "Failed to install Erigon"
        return 1
    fi

    log_info "Installing Lighthouse consensus client..."
    if ! ./install/consensus/lighthouse.sh; then
        log_error "Failed to install Lighthouse"
        return 1
    fi

    log_info "Installing MEV Boost..."
    if ! ./install/mev/install_mev_boost.sh; then
        log_error "Failed to install MEV Boost"
        return 1
    fi

    log_info "Performance setup completed successfully!"
    return 0
}

install_lightweight_setup() {
    log_info "Installing lightweight setup (Geth + Nimbus + MEV Boost)..."
    
    # Stop any existing services
    sudo systemctl stop eth1 cl validator mev 2>/dev/null || true
    
    log_info "Installing Geth execution client..."
    if ! ./install/execution/install_geth.sh; then
        log_error "Failed to install Geth"
        return 1
    fi

    log_info "Installing Nimbus consensus client..."
    if ! ./install/consensus/install_nimbus.sh; then
        log_error "Failed to install Nimbus"
        return 1
    fi

    log_info "Installing MEV Boost..."
    if ! ./install/mev/install_mev_boost.sh; then
        log_error "Failed to install MEV Boost"
        return 1
    fi

    log_info "Lightweight setup completed successfully!"
    return 0
}

install_enterprise_setup() {
    log_info "Installing enterprise setup (Nethermind + Teku + MEV Boost)..."
    
    # Stop any existing services
    sudo systemctl stop eth1 cl validator mev 2>/dev/null || true
    
    log_info "Installing Nethermind execution client..."
    if ! ./install/execution/install_nethermind.sh; then
        log_error "Failed to install Nethermind"
        return 1
    fi

    log_info "Installing Teku consensus client..."
    if ! ./install/consensus/install_teku.sh; then
        log_error "Failed to install Teku"
        return 1
    fi

    log_info "Installing MEV Boost..."
    if ! ./install/mev/install_mev_boost.sh; then
        log_error "Failed to install MEV Boost"
        return 1
    fi

    log_info "Enterprise setup completed successfully!"
    return 0
}

show_client_info() {
    echo -e "${BOLD}${UNDERLINE}AVAILABLE CLIENTS${NC}"
    echo
    echo -e "${BOLD}Execution Clients:${NC}"
    echo "• Geth (Go) - Most stable, beginner-friendly"
    echo "• Erigon (Go) - Fast sync, efficient"
    echo "• Reth (Rust) - Modern, high performance"
    echo "• Nethermind (.NET) - Enterprise features"
    echo "• Besu (Java) - Private networks, compliance"
    echo
    echo -e "${BOLD}Consensus Clients:${NC}"
    echo "• Prysm (Go) - Well documented, reliable"
    echo "• Lighthouse (Rust) - Security focused, fast"
    echo "• Teku (Java) - Institutional features"
    echo "• Nimbus (Nim) - Lightweight, resource efficient"
    echo "• Lodestar (TypeScript) - Developer friendly"
    echo "• Grandine (Rust) - High performance, cutting edge"
    echo
    echo -e "${BOLD}Installation Scripts:${NC}"
    echo "Execution: ./install/execution/install_[client].sh"
    echo "Consensus: ./install/consensus/install_[client].sh"
    echo "MEV Boost: ./install/mev/install_mev_boost.sh"
    echo
}

main_menu() {
    while true; do
        display_header
        show_installation_options
        
        read -r -p "Select an option (1-7): " choice
        if ! validate_menu_choice "$choice" 7; then
            log_error "Invalid choice. Please select 1-7."
            continue
        fi
        
        case $choice in
            1) 
                if install_default_setup; then
                    log_info "Installation completed! Services are starting..."
                    echo "Check status with: sudo systemctl status eth1 cl validator mev"
                fi
                read -r -p "Press Enter to continue..."
                ;;
            2) 
                if install_performance_setup; then
                    log_info "Installation completed! Services are starting..."
                    echo "Check status with: sudo systemctl status eth1 cl validator mev"
                fi
                read -r -p "Press Enter to continue..."
                ;;
            3) 
                if install_lightweight_setup; then
                    log_info "Installation completed! Services are starting..."
                    echo "Check status with: sudo systemctl status eth1 cl validator mev"
                fi
                read -r -p "Press Enter to continue..."
                ;;
            4) 
                if install_enterprise_setup; then
                    log_info "Installation completed! Services are starting..."
                    echo "Check status with: sudo systemctl status eth1 cl validator mev"
                fi
                read -r -p "Press Enter to continue..."
                ;;
            5) 
                show_client_info
                read -r -p "Press Enter to continue..."
                ;;
            6) 
                show_client_info
                read -r -p "Press Enter to continue..."
                ;;
            7) 
                log_info "Thank you for using the Ethereum Client Installation Assistant!"
                exit 0
                ;;
            *) 
                log_error "Invalid option. Please select 1-7."
                ;;
        esac
        clear
    done
}

# Run the main menu
main_menu