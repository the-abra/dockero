#!/usr/bin/env bash
# title: Connecting Containers with Networks

run_lesson() {
    _heading "📚 Basics: Connecting Containers with Networks"

    _subheading "What are Docker Networks?"
    echo "Docker networks allow containers to communicate with each other and with the host machine."
    echo "Without networks, containers would be completely isolated."
    echo ""
    echo -e "  Think of it like a virtual switch that connects your containers."
    echo ""

    _press_enter_to_continue

    _subheading "Built-in Network Types"
    echo "Docker provides several built-in network drivers:"
    echo -e "  ${BOLD_GREEN}bridge${RESET_COLOR}: The default network type. Containers on the same bridge network can communicate by IP address."
    echo -e "  ${BOLD_GREEN}host${RESET_COLOR}: Containers share the host's network stack. Less isolated, but can be faster."
    echo -e "  ${BOLD_GREEN}none${RESET_COLOR}: The container is completely isolated, no network interfaces are attached."
    echo ""

    _press_enter_to_continue

    _subheading "Custom Networks"
    echo "For multi-container applications, it's best practice to create custom bridge networks."
    echo "Containers on a custom bridge network can resolve each other by their container names."
    _present_command "dockero net new my-app-network" "Creates a new custom network named 'my-app-network'."
    echo ""
    _present_command "dockero create my-web-app nginx" "Runs 'my-web-app' (nginx). To connect it to a network, use 'dockero net add my-web-app my-app-network'."
    echo ""

    _press_enter_to_continue

    _subheading "Networks in Dockero"
    echo "Dockero simplifies network management:"
    echo -e "  ${BOLD_GREEN}dockero net new <name>${RESET_COLOR}: Create custom networks."
    echo -e "  ${BOLD_GREEN}dockero net list${RESET_COLOR}: List all Docker networks."
    echo -e "  When using ${BOLD_GREEN}dockero compose${RESET_COLOR}, networks are often created and managed automatically."
    echo ""

    _press_enter_to_continue

    _subheading "Summary"
    echo "You've learned:"
    echo -e "  Docker networks enable container communication."
    echo -e "  Common network types: bridge, host, none."
    echo -e "  How to create and use custom networks for better service discovery."
    echo ""
    echo "This concludes the basic topics. You can now try 'dockero learn intermediate'."
}
