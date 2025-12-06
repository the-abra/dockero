#!/usr/bin/env python3
"""
Dockero Python Helper
Provides enhanced UX features using Python libraries
"""

import sys
import os
import argparse

# Add the extra directory to the path to import our modules
sys.path.insert(0, os.path.dirname(__file__))

# Placeholder for create_container_interactive since it's not fully implemented in our TUI
def create_container_interactive():
    print("Interactive container creation is not fully implemented in the TUI.")
    print("Use 'dockero run <name> <image>' instead.")

# Run the interactive dashboard - import and call the main function from interactive_tui
def run_interactive_dashboard():
    from interactive_tui import main as tui_main
    tui_main()

from progress_indicator import demo_progress_indicators, run_docker_pull_with_progress, run_docker_build_with_progress, run_container_start_with_progress


def main():
    parser = argparse.ArgumentParser(description='Dockero Python Helper for Enhanced UX')
    parser.add_argument('command', nargs='?', help='Command to run')
    parser.add_argument('--image', help='Image name for operations')
    parser.add_argument('--container', help='Container name for operations')
    parser.add_argument('--tag', help='Tag for build operations')
    parser.add_argument('--context', help='Context path for build operations')

    args = parser.parse_args()

    if args.command == 'tui' or args.command == 'dashboard':
        # Ensure proper terminal handling
        import os
        os.environ.setdefault('TERM', 'xterm-256color')
        run_interactive_dashboard()
    elif args.command == 'progress-demo':
        demo_progress_indicators()
    elif args.command == 'pull':
        if args.image:
            run_docker_pull_with_progress(args.image)
        else:
            print("Error: --image argument required for pull command")
            sys.exit(1)
    elif args.command == 'build':
        if args.tag and args.context:
            run_docker_build_with_progress(args.context, args.tag)
        else:
            print("Error: --tag and --context arguments required for build command")
            sys.exit(1)
    elif args.command == 'start':
        if args.container:
            run_container_start_with_progress(args.container)
        else:
            print("Error: --container argument required for start command")
            sys.exit(1)
    else:
        print("Dockero Python Helper")
        print("Commands:")
        print("  tui, dashboard           - Run interactive TUI dashboard")
        print("  progress-demo            - Demo progress indicators")
        print("  pull --image <name>      - Pull image with progress")
        print("  build --tag <name> --context <path>  - Build image with progress")
        print("  start --container <name> - Start container with progress")
        print("")
        print("Usage: python3 dockero_helper.py <command> [options]")


if __name__ == "__main__":
    main()