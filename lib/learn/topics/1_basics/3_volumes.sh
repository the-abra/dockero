#!/usr/bin/env bash
# title: Persistent Data with Volumes

run_lesson() {
    _heading "📚 Basics: Persistent Data with Volumes"

    _subheading "Why do we need Volumes?"
    echo "Containers are designed to be temporary. If you remove a container, any data"
    echo "written inside it is lost forever."
    echo ""
    log.sub "Volumes solve this by allowing you to store data outside the container's filesystem."
    log.sub "They connect a path on your host machine to a path inside the container."
    echo ""

    _press_enter_to_continue

    _subheading "Volume Format"
    echo "The common format for specifying a volume is:"
    _present_code "HOST_PATH:CONTAINER_PATH"
    echo ""
    log.sub "Example: ./data:/app/data"
    log.sub "This means the 'data' folder in your current directory (HOST_PATH) is linked"
    log.sub "to the '/app/data' folder inside your container (CONTAINER_PATH)."
    echo ""

    _press_enter_to_continue

    _subheading "Volumes in Dockero"
    echo "Dockero uses volumes extensively for development and data persistence."
    log.sub "When you use ${BOLD_GREEN}dockero setup .${RESET_COLOR}, your project directory is typically mounted as a volume."
    log.sub "The ${BOLD_GREEN}dockero volume${RESET_COLOR} command lets you create, inspect, and manage persistent volumes."
    log.sub "You can define volumes in your '.dockero' configuration files."
    echo ""

    _press_enter_to_continue

    _subheading "Summary"
    echo "You've learned:"
    log.sub "Containers are temporary, and data can be lost without volumes."
    log.sub "Volumes connect host and container filesystems for persistent data."
    log.sub "The format for specifying volumes is HOST_PATH:CONTAINER_PATH."
    echo ""
    log.info "Next, we'll learn about Networks."
}
