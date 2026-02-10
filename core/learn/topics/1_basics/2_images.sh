#!/usr/bin/env bash
# title: Understanding Images

run_lesson() {
    _heading "📚 Basics: Understanding Images"

    _subheading "What are Docker Images?"
    echo "Images are the read-only templates from which containers are built."
    echo "They contain the application, libraries, dependencies, and configuration."
    echo ""
    log.sub "Think of an image as a blueprint, and a container as a house built from that blueprint."
    echo ""

    _press_enter_to_continue

    _subheading "Common Image Formats"
    echo "Images often include the base OS and the application version:"
    log.sub "ubuntu:20.04 - Ubuntu operating system, version 20.04"
    log.sub "nginx:latest - NGINX web server, latest version"
    log.sub "node:16-alpine - Node.js version 16 on Alpine Linux (a very small base OS)"
    echo ""

    _press_enter_to_continue

    _subheading "Finding and Listing Images"
    echo "Docker images are typically stored in registries like Docker Hub."
    echo "Dockero automatically pulls images when you need them."
    _present_command "dockero list --images" "This command shows all Docker images currently stored on your system."
    log.info "You can also explore Docker Hub directly in your browser."
    echo ""

    _press_enter_to_continue

    _subheading "Summary"
    echo "You've learned:"
    log.sub "Images are blueprints for containers."
    log.sub "They include everything needed to run an application."
    log.sub "How to list images on your system."
    echo ""
    log.info "Next, we'll learn about Volumes for persistent data."
}
