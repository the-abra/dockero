#!/usr/bin/env bash
# title: What is a Container?

run_lesson() {
    _heading "📚 Basics: What is a Container?"

    _subheading "What are containers?"
    echo "Containers are like tiny, isolated computers that run a single application."
    echo "They package an application and all its dependencies together."
    echo ""
    echo "Think of it like this:"
    log.sub "Image: A blueprint for a house (e.g., Ubuntu, nginx)."
    log.sub "Container: An actual house built from the blueprint."
    echo ""

    _press_enter_to_continue

    _subheading "Let's run your first container!"
    _present_command "dockero create my-first-container hello-world" "This will download the 'hello-world' image and create a container named 'my-first-container'."

    # This is a bit of a trick, we are not actually running the command here, just showing it.
    # A more advanced version could actually execute it.

    echo "When you run this, Docker does the following:"
    log.sub "1. Checks if you have the 'hello-world' image locally."
    log.sub "2. If not, it downloads it from Docker Hub."
    log.sub "3. It creates a new container from that image."
    log.sub "4. It runs the container, which prints a message and then exits."

    _press_enter_to_continue

    _subheading "Container Lifecycle"
    echo "Containers have a simple lifecycle:"
    log.sub "CREATE -> START -> STOP -> DELETE"
    echo ""
    echo "You can manage this with these dockero commands:"
    _present_code "dockero create <name> <image> # Create and start"
    _present_code "dockero start <name>       # Start a stopped container"
    _present_code "dockero stop <name>        # Stop a running container"
    _present_code "dockero remove <name>      # Delete a container"
    
    _press_enter_to_continue
    
    _subheading "Summary"
    echo "You've learned:"
    log.sub "What containers and images are."
    log.sub "How to run your first container."
    log.sub "The basic lifecycle of a container."
    echo ""
    log.info "Next, we'll learn more about Images."
}
