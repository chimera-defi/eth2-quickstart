#!/bin/bash

# Quick Client Installation Script
# Provides streamlined client installation without questionnaires

source ../../lib/common_functions.sh

# Colors for better readability
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_quick_options() {
    echo -e "${BOLD}${GREEN}Ethereum Client Quick Install${NC}"
    echo "=================================="
    echo
    echo "Choose a preset configuration:"
    echo
    echo "1. Default Setup (Geth + Prysm + MEV Boost) - Recommended"
    echo "2. Performance Setup (Erigon + Lighthouse + MEV Boost)"
    echo "3. Lightweight Setup (Geth + Nimbus + MEV Boost)"
    echo "4. Enterprise Setup (Nethermind + Teku + MEV Boost)"
    echo "5. Custom Selection (Choose individual clients)"
    echo
}

install_default_setup() {
    log_info "Installing Default Setup (Geth + Prysm + MEV Boost)..."
    
    log_info "Installing Geth..."
    if ! ./install/execution/install_geth.sh; then
        log_error "Failed to install Geth"
        return 1
    fi

    log_info "Installing Prysm..."
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
    log_info "Installing Performance Setup (Erigon + Lighthouse + MEV Boost)..."
    
    log_info "Installing Erigon..."
    if ! ./install/execution/erigon.sh; then
        log_error "Failed to install Erigon"
        return 1
    fi

    log_info "Installing Lighthouse..."
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
    log_info "Installing Lightweight Setup (Geth + Nimbus + MEV Boost)..."
    
    log_info "Installing Geth..."
    if ! ./install/execution/install_geth.sh; then
        log_error "Failed to install Geth"
        return 1
    fi

    log_info "Installing Nimbus..."
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
    log_info "Installing Enterprise Setup (Nethermind + Teku + MEV Boost)..."
    
    log_info "Installing Nethermind..."
    if ! ./install/execution/install_nethermind.sh; then
        log_error "Failed to install Nethermind"
        return 1
    fi

    log_info "Installing Teku..."
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

show_custom_options() {
    echo -e "${BOLD}${YELLOW}Custom Client Selection${NC}"
    echo "====================="
    echo
    echo "Execution Clients:"
    echo "1. Geth (Go) - Most stable"
    echo "2. Erigon (Go) - High performance"
    echo "3. Reth (Rust) - Modern, fast"
    echo "4. Nethermind (.NET) - Enterprise features"
    echo "5. Besu (Java) - Apache licensed"
    echo
    echo "Consensus Clients:"
    echo "6. Prysm (Go) - Well documented"
    echo "7. Lighthouse (Rust) - High performance"
    echo "8. Teku (Java) - Enterprise features"
    echo "9. Nimbus (Nim) - Lightweight"
    echo "10. Lodestar (TypeScript) - Developer friendly"
    echo "11. Grandine (Rust) - High performance"
    echo
    echo "MEV Boost:"
    echo "12. Flashbots MEV Boost - Recommended"
    echo
    echo "Enter numbers separated by spaces (e.g., '1 6 12' for Geth + Prysm + MEV Boost):"
    read -r -p "Selection: " custom_choice
    
    # Parse selection and install
    for choice in $custom_choice; do
        case $choice in
            1) log_info "Installing Geth..."; ./install/execution/install_geth.sh ;;
            2) log_info "Installing Erigon..."; ./install/execution/erigon.sh ;;
            3) log_info "Installing Reth..."; ./install/execution/reth.sh ;;
            4) log_info "Installing Nethermind..."; ./install/execution/install_nethermind.sh ;;
            5) log_info "Installing Besu..."; ./install/execution/install_besu.sh ;;
            6) log_info "Installing Prysm..."; ./install/consensus/install_prysm.sh ;;
            7) log_info "Installing Lighthouse..."; ./install/consensus/lighthouse.sh ;;
            8) log_info "Installing Teku..."; ./install/consensus/install_teku.sh ;;
            9) log_info "Installing Nimbus..."; ./install/consensus/install_nimbus.sh ;;
            10) log_info "Installing Lodestar..."; ./install/consensus/install_lodestar.sh ;;
            11) log_info "Installing Grandine..."; ./install/consensus/install_grandine.sh ;;
            12) log_info "Installing MEV Boost..."; ./install/mev/install_mev_boost.sh ;;
            *) log_warn "Invalid selection: $choice" ;;
        esac
    done
}

main() {
    show_quick_options
    read -r -p "Select option (1-5): " choice
    
    case $choice in
        1) install_default_setup ;;
        2) install_performance_setup ;;
        3) install_lightweight_setup ;;
        4) install_enterprise_setup ;;
        5) show_custom_options ;;
        *) 
            log_error "Invalid selection. Installing default setup..."
            install_default_setup
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        log_info "Client installation completed successfully!"
        show_log_location
    else
        log_error "Client installation failed. Check logs for details."
        exit 1
    fi
}

# Run main function
main