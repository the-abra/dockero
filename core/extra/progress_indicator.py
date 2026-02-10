#!/usr/bin/env python3
"""
Progress and status indicators for Dockero operations
Uses rich library for enhanced visual feedback
"""

import sys
import time
from typing import Callable, Any
import subprocess

try:
    from rich.progress import Progress, SpinnerColumn, BarColumn, TextColumn, TimeRemainingColumn, TaskID
    from rich.console import Console
    from rich.panel import Panel
    from rich.text import Text
except ImportError:
    print("Rich library not installed. Install with: pip3 install rich")
    sys.exit(1)


class ProgressIndicator:
    """Enhanced progress and status indicators for Dockero operations"""

    def __init__(self):
        # Force terminal compatibility for Kitty and other terminals
        import os
        os.environ.setdefault('TERM', 'xterm-256color')

        # Initialize console with forced terminal mode
        self.console = Console(force_terminal=True)
        self.progress = None
        self.current_task = None
    
    def create_progress_bar(self):
        """Create a rich progress bar instance"""
        self.progress = Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
            TimeRemainingColumn(),
            console=self.console
        )
        return self.progress
    
    def show_simple_spinner(self, message: str, operation: Callable[[], Any] = None):
        """Show a simple spinner while an operation is running"""
        with self.progress:
            task_id = self.progress.add_task(description=message, total=None)
            
            if operation:
                try:
                    result = operation()
                    self.progress.update(task_id, description=f"[green]✓ {message} completed[/green]", completed=100)
                    return result
                except Exception as e:
                    self.progress.update(task_id, description=f"[red]✗ {message} failed: {str(e)}[/red]", completed=100)
                    raise e
    
    def show_progress_bar(self, message: str, total: int, operation: Callable[[TaskID], Any] = None):
        """Show a progress bar with specific total for an operation"""
        with self.progress:
            task_id = self.progress.add_task(description=message, total=total)
            
            if operation:
                try:
                    result = operation(task_id)
                    self.progress.update(task_id, completed=total, description=f"[green]✓ {message} completed[/green]")
                    return result
                except Exception as e:
                    self.progress.update(task_id, completed=total, description=f"[red]✗ {message} failed: {str(e)}[/red]")
                    raise e
    
    def track_docker_operation(self, command: str, description: str):
        """Track a docker operation and show visual progress"""
        # First, we'll create a simple progress without explicit completion tracking
        # since we don't always know how long operations will take
        with self.progress:
            task_id = self.progress.add_task(description=description, total=None)
            
            try:
                # Execute the command
                result = subprocess.run(
                    command,
                    shell=True,
                    capture_output=True,
                    text=True
                )
                
                if result.returncode == 0:
                    self.progress.update(task_id, description=f"[green]✓ {description} completed[/green]", completed=100)
                    return True, result.stdout
                else:
                    self.progress.update(task_id, description=f"[red]✗ {description} failed: {result.stderr}[/red]", completed=100)
                    return False, result.stderr
            except Exception as e:
                self.progress.update(task_id, description=f"[red]✗ {description} failed: {str(e)}[/red]", completed=100)
                return False, str(e)
    
    def show_loading_animation(self, message: str, duration: float = 5.0):
        """Show a loading animation for indeterminate operations"""
        with self.progress:
            task_id = self.progress.add_task(description=message, total=None)
            
            start_time = time.time()
            while time.time() - start_time < duration:
                time.sleep(0.1)  # Small delay to allow for animation
            
            self.progress.update(task_id, description=f"[green]✓ {message} completed[/green]", completed=100)
    
    def show_status_update(self, message: str, status: str = "progress"):
        """Show a status update in a panel format"""
        status_colors = {
            "progress": "blue",
            "success": "green", 
            "warning": "yellow",
            "error": "red"
        }
        
        color = status_colors.get(status, "white")
        status_text = f"[{color}]{message}[/{color}]"
        
        panel = Panel(
            status_text,
            title=f"Status - {status.capitalize()}",
            border_style=color
        )
        
        self.console.print(panel)
    
    def show_detailed_status(self, title: str, items: list):
        """Show detailed status information in a table format"""
        from rich.table import Table
        
        table = Table(title=title, expand=True)
        table.add_column("Item", style="cyan", no_wrap=True)
        table.add_column("Status", style="magenta")
        table.add_column("Details", style="green")
        
        for item in items:
            table.add_row(item.get('name', ''), item.get('status', ''), item.get('details', ''))
        
        self.console.print(table)


def run_docker_pull_with_progress(image_name: str):
    """Example function showing how to use progress tracking for docker pull"""
    pi = ProgressIndicator()
    pi.create_progress_bar()
    
    command = f"docker pull {image_name}"
    success, output = pi.track_docker_operation(command, f"Pulling image: {image_name}")
    
    if success:
        pi.show_status_update(f"Successfully pulled {image_name}", "success")
        return True
    else:
        pi.show_status_update(f"Failed to pull {image_name}", "error")
        return False


def run_docker_build_with_progress(context_path: str, tag: str):
    """Example function showing how to use progress tracking for docker build"""
    pi = ProgressIndicator()
    pi.create_progress_bar()
    
    command = f"docker build -t {tag} {context_path}"
    success, output = pi.track_docker_operation(command, f"Building image: {tag}")
    
    if success:
        pi.show_status_update(f"Successfully built {tag}", "success")
        return True
    else:
        pi.show_status_update(f"Failed to build {tag}", "error")
        return False


def run_container_start_with_progress(container_name: str):
    """Example function showing how to use progress tracking for starting containers"""
    pi = ProgressIndicator()
    pi.create_progress_bar()
    
    command = f"docker start {container_name}"
    success, output = pi.track_docker_operation(command, f"Starting container: {container_name}")
    
    if success:
        pi.show_status_update(f"Successfully started {container_name}", "success")
        return True
    else:
        pi.show_status_update(f"Failed to start {container_name}", "error")
        return False


def run_operation_with_custom_progress(operation_func: Callable, description: str, *args, **kwargs):
    """Run an operation with custom progress tracking"""
    pi = ProgressIndicator()
    pi.create_progress_bar()
    
    def operation_wrapper(task_id):
        return operation_func(*args, **kwargs)
    
    try:
        result = pi.show_progress_bar(description, 100, operation_wrapper)
        return result
    except Exception as e:
        pi.show_status_update(f"Operation failed: {str(e)}", "error")
        return None


def demo_progress_indicators():
    """Demonstrate the progress indicators"""
    pi = ProgressIndicator()
    pi.create_progress_bar()
    
    # Demo 1: Simple spinner
    pi.show_status_update("Starting demo of progress indicators", "progress")
    
    def demo_operation():
        time.sleep(2)  # Simulate work
        return "Operation completed!"
    
    pi.show_simple_spinner("Processing data", demo_operation)
    
    # Demo 2: Status updates
    pi.show_status_update("Docker daemon check", "progress")
    time.sleep(0.5)
    pi.show_status_update("Docker daemon active", "success")
    
    # Demo 3: Loading animation
    pi.show_loading_animation("Initializing", 2.0)
    
    pi.show_status_update("All demos completed", "success")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "demo":
        demo_progress_indicators()
    elif len(sys.argv) > 1 and sys.argv[1] == "pull":
        if len(sys.argv) > 2:
            run_docker_pull_with_progress(sys.argv[2])
        else:
            print("Usage: python3 progress_indicator.py pull <image_name>")
    else:
        demo_progress_indicators()