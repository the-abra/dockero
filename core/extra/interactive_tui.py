#!/usr/bin/env python3
"""
Interactive TUI for Dockero - Docker Manager
This module provides a terminal user interface for Docker management with:
- Left panel: Containers (top) and Images (bottom)
- Right panel: Actions and information
"""

import os
import sys
import subprocess
import threading
import time
from typing import List, Dict, Any
from dataclasses import dataclass
from textual.message import Message

try:
    import docker
    from textual.app import App, ComposeResult
    from textual.containers import Container, Vertical, Horizontal
    from textual.widgets import Static, DataTable, Button, Label, Input
    from textual import events
    from textual.reactive import reactive
except ImportError as e:
    print(f"Missing required dependencies: {e}")
    print("Please install required packages with: pip install docker textual")
    sys.exit(1)


@dataclass
class ContainerInfo:
    id: str
    name: str
    image: str
    status: str
    ports: str
    command: str


@dataclass
class ImageInfo:
    id: str
    repository: str
    tag: str
    size: str


class ContainerSelected(Message):
    """Message posted when a container is selected."""
    def __init__(self, container_id: str, container_name: str) -> None:
        self.container_id = container_id
        self.container_name = container_name
        super().__init__()


class ImageSelected(Message):
    """Message posted when an image is selected."""
    def __init__(self, image_id: str, repository: str, tag: str) -> None:
        self.image_id = image_id
        self.repository = repository
        self.tag = tag
        super().__init__()


class DockerHubSearchInput(Static):
    """Widget for searching DockerHub images."""
    
    def __init__(self) -> None:
        super().__init__()
        self.search_term = ""
    
    def compose(self) -> ComposeResult:
        yield Input(placeholder="Search DockerHub...", id="dockerhub_search")
    
    def on_input_changed(self, event: Input.Changed) -> None:
        """Handle search input changes for live search."""
        self.search_term = event.value
        # This would trigger a search in a real implementation
        if hasattr(self.parent, 'handle_dockerhub_search'):
            self.parent.handle_dockerhub_search(self.search_term)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        """Handle search submission."""
        if hasattr(self.parent, 'handle_dockerhub_search'):
            self.parent.handle_dockerhub_search(self.search_term)


class ContainerTable(Static):
    """Widget to display containers in a table format"""
    
    selected_container_id = reactive("")
    
    def __init__(self) -> None:
        super().__init__()
        self.client = docker.from_env()
        self.containers: List[ContainerInfo] = []
        self.table = DataTable(id="containers_table", zebra_stripes=True)
        self.table.add_columns("ID", "Name", "Image", "Status", "Command")
        self.table.zebra_stripes = True
        self.table.cursor_type = "row"  # Make the table selectable by rows
    
    def refresh_containers(self):
        """Refresh the list of containers"""
        try:
            # Use the application's Docker client if available, otherwise create a new one
            client = getattr(self.app, 'docker_client', None)
            if not client:
                client = docker.from_env()

            raw_containers = client.containers.list(all=True)
            self.containers = []

            # Collect all rows first, then clear and add them all at once for better performance
            rows_to_add = []
            for container in raw_containers:
                # Safely extract container information
                image_tags = container.image.tags if hasattr(container, 'image') and container.image else []
                image_name = image_tags[0] if image_tags else "<none>"

                # Safely extract command
                config = container.attrs.get("Config", {})
                command = config.get("Cmd", [""])[0] if config.get("Cmd") else ""
                command = command if command else ""

                container_info = ContainerInfo(
                    id=container.short_id,
                    name=container.name,
                    image=image_name,
                    status=container.status,
                    ports="",
                    command=command
                )
                self.containers.append(container_info)

                status_color = "green" if "running" in container.status.lower() else "red"
                rows_to_add.append((
                    container_info.id,
                    container_info.name,
                    container_info.image,
                    f"[{status_color}]{container_info.status}[/{status_color}]",
                    container_info.command[:50] + "..." if len(container_info.command) > 50 else container_info.command
                ))

            # Clear existing rows and add new ones in batch
            self.table.clear()
            for row in rows_to_add:
                self.table.add_row(*row)

        except Exception as e:
            # Log to stderr instead of print for better error handling
            import logging
            logging.error(f"Error refreshing containers: {e}")
            # Optionally notify the user via UI
            if hasattr(self, 'app') and hasattr(self.app, 'notify'):
                self.app.notify(f"Error refreshing containers: {str(e)}", severity="error")
    
    def compose(self) -> ComposeResult:
        yield self.table
    
    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        """Handle row selection in the container table"""
        # Get the selected row data
        row_key = event.cursor_row
        if 0 <= row_key < len(self.containers):
            selected_container = self.containers[row_key]
            self.selected_container_id = selected_container.id
            # Notify the main app about the selection
            self.post_message(ContainerSelected(container_id=selected_container.id, 
                                              container_name=selected_container.name))


class ImageTable(Static):
    """Widget to display images in a table format"""
    
    selected_image_id = reactive("")
    
    def __init__(self) -> None:
        super().__init__()
        self.client = docker.from_env()
        self.images: List[ImageInfo] = []
        self.table = DataTable(id="images_table", zebra_stripes=True)
        self.table.add_columns("ID", "Repository", "Tag", "Size")
        self.table.zebra_stripes = True
        self.table.cursor_type = "row"  # Make the table selectable by rows
    
    def refresh_images(self):
        """Refresh the list of images"""
        try:
            # Use the application's Docker client if available, otherwise create a new one
            client = getattr(self.app, 'docker_client', None)
            if not client:
                client = docker.from_env()

            raw_images = client.images.list()
            self.images = []

            # Collect all rows first, then clear and add them all at once for better performance
            rows_to_add = []
            for image in raw_images:
                # Handle images with no tags (dangling images)
                if not image.tags:
                    # Skip or handle dangling images differently
                    continue

                for tag in image.tags:
                    repo, tag_name = tag.split(':') if ':' in tag else (tag, 'latest')
                    # Safely calculate size
                    try:
                        size_bytes = image.attrs.get('Size', 0)
                        size_mb = size_bytes / (1024*1024) if size_bytes else 0
                        size_str = f"{size_mb:.1f}MB"
                    except:
                        size_str = "Unknown"

                    image_info = ImageInfo(
                        id=image.short_id.replace('sha256:', '')[:12],
                        repository=repo,
                        tag=tag_name,
                        size=size_str
                    )
                    self.images.append(image_info)
                    rows_to_add.append((
                        image_info.id,
                        image_info.repository,
                        image_info.tag,
                        image_info.size
                    ))

            # Clear existing rows and add new ones in batch
            self.table.clear()
            for row in rows_to_add:
                self.table.add_row(*row)

        except Exception as e:
            # Log to stderr instead of print for better error handling
            import logging
            logging.error(f"Error refreshing images: {e}")
            # Optionally notify the user via UI
            if hasattr(self, 'app') and hasattr(self.app, 'notify'):
                self.app.notify(f"Error refreshing images: {str(e)}", severity="error")
    
    def compose(self) -> ComposeResult:
        yield self.table
    
    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        """Handle row selection in the image table"""
        # Get the selected row data
        row_key = event.cursor_row
        if 0 <= row_key < len(self.images):
            selected_image = self.images[row_key]
            self.selected_image_id = selected_image.id
            # Notify the main app about the selection
            self.post_message(ImageSelected(image_id=selected_image.id, 
                                          repository=selected_image.repository,
                                          tag=selected_image.tag))


class ActionsPanel(Static):
    """Widget to display actions and quick commands"""
    
    def __init__(self) -> None:
        super().__init__()
        self.selected_container_id = ""
        self.selected_image_id = ""
        self.selected_repository = ""
        self.selected_tag = ""
    
    def compose(self) -> ComposeResult:
        yield Label("[b]Quick Actions:[/b]", id="actions-title")
        yield Button("Start Container", id="start_container", variant="success")
        yield Button("Stop Container", id="stop_container", variant="warning")
        yield Button("Remove Container", id="remove_container", variant="error")
        yield Button("Pull Image", id="pull_image", variant="primary")
        yield Button("Remove Image", id="remove_image", variant="error")
        yield Button("Refresh", id="refresh", variant="default")

        yield Label("\n[b]Pull Image:[/b]", id="pull-title")
        yield Input(placeholder="Enter image name (e.g., nginx:latest)", id="pull_image_input")

        # Status display for image pulling
        self.pull_status_label = Label("", id="pull_status")
        yield self.pull_status_label

        yield Label("\n[b]Docker Stats:[/b]", id="stats-title")
        stats_label = Label(id="stats_label")
        yield stats_label
    
    def set_selected_container(self, container_id: str, container_name: str):
        """Update the selected container info"""
        self.selected_container_id = container_id
        self.notify(f"Selected container: {container_name} ({container_id[:12]})")
    
    def set_selected_image(self, image_id: str, repository: str, tag: str):
        """Update the selected image info"""
        self.selected_image_id = image_id
        self.selected_repository = repository
        self.selected_tag = tag
        self.notify(f"Selected image: {repository}:{tag} ({image_id[:12]})")
    
    def update_stats(self):
        """Update stats display"""
        try:
            # Use the application's Docker client if available, otherwise create a new one
            client = getattr(self.app, 'docker_client', None)
            if not client:
                client = docker.from_env()

            containers = client.containers.list(all=True)
            running = len(client.containers.list(filters={'status': 'running'}))
            images = len(client.images.list())

            stats_text = f"Containers: Total={len(containers)}, Running={running}\nImages: {images}"
            try:
                self.query_one("#stats_label", Label).update(stats_text)
            except:
                # Label might not be ready yet
                pass
        except Exception as e:
            # Log the error
            import logging
            logging.error(f"Error getting stats: {e}")
            try:
                self.query_one("#stats_label", Label).update(f"Error getting stats: {e}")
            except:
                # Fallback if UI element isn't ready
                pass


class DockeroTUI(App):
    """Main application for the Dockero TUI"""

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("r", "refresh", "Refresh"),
        ("tab", "focus_next", "Focus Next Widget"),
    ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Initialize Docker client once for the application
        try:
            self.docker_client = docker.from_env()
        except Exception as e:
            # Handle Docker not being available
            import logging
            logging.error(f"Docker client initialization failed: {e}")
            self.docker_client = None
    
    CSS = """
    Screen {
        layout: horizontal;
        background: $panel;
    }
    
    #left-panel {
        width: 70%;
        height: 100%;
        layout: vertical;
    }
    
    #containers-section {
        height: 1fr;  /* Flexible height to fill available space */
        border: solid $primary 50%;
        margin: 1;
        padding: 1;
        background: $boost;
    }
    
    #containers-header {
        text-style: bold;
        padding: 0 1;
        content-align: center middle;
        background: $primary 10%;
    }
    
    #images-section {
        height: 1fr;  /* Flexible height to fill available space */
        border: solid $primary 50%;
        margin: 1;
        padding: 1;
        background: $boost;
    }
    
    #images-header {
        text-style: bold;
        padding: 0 1;
        content-align: center middle;
        background: $primary 10%;
    }
    
    #right-panel {
        width: 30%;
        border: solid $primary 50%;
        margin: 1;
        padding: 1;
        background: $boost;
    }
    
    #actions-header {
        text-style: bold;
        padding: 0 1;
        content-align: center middle;
        background: $primary 10%;
    }
    
    #actions-title {
        text-style: bold;
        color: $success;
    }
    
    #pull-title {
        text-style: bold;
        color: $accent;
    }

    #pull_status {
        text-style: italic;
        color: $warning;
        padding: 0 1;
    }
    
    #stats-title {
        text-style: bold;
        color: $warning;
    }
    
    DataTable {
        height: 1fr;
        width: 1fr;
        border: none;
        background: $surface;
    }
    
    Button {
        margin: 1 0;
        min-width: 24;
        background: $primary;
        color: $text;
    }
    
    Button:hover {
        background: $primary-lighten-1;
        text-style: bold;
    }
    
    Button.success {
        background: $success;
    }
    
    Button.success:hover {
        background: $success-lighten-1;
    }
    
    Button.warning {
        background: $warning;
    }
    
    Button.warning:hover {
        background: $warning-lighten-1;
    }
    
    Button.error {
        background: $error;
    }
    
    Button.error:hover {
        background: $error-lighten-1;
    }
    
    Label {
        margin: 1 0;
        color: $text;
    }
    
    Static {
        background: transparent;
    }
    
    Input {
        margin: 1 0;
        width: 100%;
    }

    Input.progress-0 {
        background: $surface;
    }

    Input.progress-25 {
        background: $primary 20%;
    }

    Input.progress-50 {
        background: $primary 40%;
    }

    Input.progress-75 {
        background: $primary 60%;
    }

    Input.progress-90 {
        background: $primary 80%;
    }

    Input.progress-100 {
        background: $success 30%;
    }
    """

    def compose(self) -> ComposeResult:
        with Horizontal():
            with Vertical(id="left-panel"):
                with Container(id="containers-section"):
                    yield Static("Containers", id="containers-header")
                    yield ContainerTable()
                with Container(id="images-section"):
                    yield Static("Images", id="images-header")
                    yield ImageTable()
            # Right panel
            with Vertical(id="right-panel"):
                yield Static("Actions & Info", id="actions-header")
                yield ActionsPanel()
    
    def on_container_selected(self, message: ContainerSelected) -> None:
        """Handle container selection message"""
        actions_panel = self.query_one(ActionsPanel)
        actions_panel.set_selected_container(message.container_id, message.container_name)
        # Store for potential use in actions
        self.selected_container_id = message.container_id
        self.selected_container_name = message.container_name
    
    def on_image_selected(self, message: ImageSelected) -> None:
        """Handle image selection message"""
        actions_panel = self.query_one(ActionsPanel)
        actions_panel.set_selected_image(message.image_id, message.repository, message.tag)
        # Store for potential use in actions
        self.selected_image_id = message.image_id
        self.selected_repository = message.repository
        self.selected_tag = message.tag
    
    def on_mount(self) -> None:
        """Called when app starts"""
        # Initialize selection tracking
        self.selected_container_id = ""
        self.selected_container_name = ""
        self.selected_image_id = ""
        self.selected_repository = ""
        self.selected_tag = ""
        
        # Calculate the height based on terminal size, with a fallback and apply to panels
        try:
            terminal_height = os.get_terminal_size().lines - 2  # Fixed height as requested: terminal_height - 2
        except OSError:
            # Fallback when not running in a terminal (e.g., CI, IDE)
            terminal_height = 23  # Use 23 as a standard size when terminal size is not available

        # Apply the calculated height to both panels
        self.query_one("#left-panel", Vertical).styles.height = terminal_height
        self.query_one("#right-panel", Vertical).styles.height = terminal_height

        # Initial data load
        self.refresh_all()

        # Set up auto-refresh
        self.set_interval(5.0, self.refresh_all)

    def on_resize(self, event: events.Resize) -> None:
        """Handle terminal resize events to maintain proper layout"""
        # Update the height of panels when terminal is resized
        new_height = event.size.height - 2
        try:
            left_panel = self.query_one("#left-panel", Vertical)
            right_panel = self.query_one("#right-panel", Vertical)

            left_panel.styles.height = new_height
            right_panel.styles.height = new_height
        except:
            # If widgets are not ready yet, ignore resize event
            pass
    
    def pull_image_in_background(self, image_name: str):
        """Pull image in background thread with progress tracking"""
        def pull_worker():
            try:
                if not self.docker_client:
                    self.call_from_thread(lambda: self.update_pull_status("Docker client not available", 0))
                    return

                client = self.docker_client
                # Update status
                self.call_from_thread(lambda: self.update_pull_status(f"Pulling {image_name}...", 0))

                # Pull the image with progress tracking
                import json
                pulled_image = None

                # Stream the pull response to track progress
                for line in client.api.pull(image_name, stream=True, decode=True):
                    # Update status with progress information
                    status = line.get("status", "")
                    progress = line.get("progress", "")
                    id = line.get("id", "")

                    if status and "Downloading" in status:
                        # Extract progress percentage if available
                        if progress and "%" in progress:
                            # Extract percentage from progress string like "[>                                                  ] 2%"
                            import re
                            percent_match = re.search(r'(\d+)%', progress)
                            if percent_match:
                                percent = int(percent_match.group(1))
                                progress_text = f"Downloading {percent}%"
                                self.call_from_thread(lambda pt=progress_text, p=percent: self.update_pull_status(pt, p))
                        else:
                            self.call_from_thread(lambda: self.update_pull_status("Downloading...", 10))
                    elif status:
                        self.call_from_thread(lambda: self.update_pull_status(f"{status}", 90))

                # Update status with success
                self.call_from_thread(lambda: self.update_pull_status(f"Successfully pulled {image_name}", 100))
                self.call_from_thread(lambda: self.refresh_all())  # Refresh to show new image
            except Exception as e:
                self.call_from_thread(lambda: self.update_pull_status(f"Error: {str(e)}", 0))

        # Start the pulling process in a separate thread
        thread = threading.Thread(target=pull_worker, daemon=True)
        thread.start()

    def update_pull_status(self, message: str, progress: int = 0):
        """Update the pull status label and show progress bar"""
        try:
            actions_panel = self.query_one(ActionsPanel)
            # Update the status message
            actions_panel.pull_status_label.update(message)

            # Update the input field's background to show progress
            input_widget = self.query_one("#pull_image_input", Input)
            # Set a different background style based on progress
            self.set_progress_background(input_widget, progress)
        except:
            pass  # Ignore if UI is not ready yet

    def set_progress_background(self, input_widget, progress):
        """Set the background of the input field to show progress"""
        # Update the input widget's CSS class to reflect progress
        # Remove any existing progress classes
        try:
            for cls in list(input_widget.classes):  # Use list() to avoid modification during iteration
                if cls.startswith('progress-'):
                    input_widget.remove_class(cls)

            # Add a class based on progress percentage
            if progress == 0:
                input_widget.add_class('progress-0')
            elif progress < 25:
                input_widget.add_class('progress-25')
            elif progress < 50:
                input_widget.add_class('progress-50')
            elif progress < 75:
                input_widget.add_class('progress-75')
            elif progress < 100:
                input_widget.add_class('progress-90')
            else:
                input_widget.add_class('progress-100')
        except Exception:
            # Ignore if UI element is not ready
            pass


    def refresh_all(self):
        """Refresh all panels"""
        try:
            if not self.docker_client:
                self.notify("Docker client not available", severity="error")
                return

            # Refresh containers
            container_widget = self.query_one(ContainerTable)
            container_widget.refresh_containers()

            # Refresh images
            image_widget = self.query_one(ImageTable)
            image_widget.refresh_images()

            # Update stats
            actions_widget = self.query_one(ActionsPanel)
            actions_widget.update_stats()

            # Update the tables by recomposing
            try:
                container_table = self.query_one("#containers_table", DataTable)
                image_table = self.query_one("#images_table", DataTable)

                container_table.clear()
                image_table.clear()

                # Repopulate tables
                for container in container_widget.containers:
                    status_color = "green" if "running" in container.status.lower() else "red"
                    container_table.add_row(
                        container.id,
                        container.name,
                        container.image,
                        f"[{status_color}]{container.status}[/{status_color}]",
                        container.command[:50] + "..." if len(container.command) > 50 else container.command
                    )

                for image in image_widget.images:
                    image_table.add_row(
                        image.id,
                        image.repository,
                        image.tag,
                        image.size
                    )
            except Exception:
                # Tables might not be ready yet
                pass
        except Exception as e:
            # Log the error
            import logging
            logging.error(f"Error in refresh_all: {e}")
            self.notify(f"Error refreshing data: {str(e)}", severity="error")
    
    def on_input_submitted(self, event: Input.Submitted) -> None:
        """Handle input submission when Enter is pressed in the pull image input"""
        if event.input.id == "pull_image_input":
            image_name = event.value.strip()
            if image_name:
                # Start pulling the image
                self.pull_image_in_background(image_name)
            else:
                self.notify("Please enter an image name to pull", severity="warning")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press events"""
        try:
            if not self.docker_client:
                self.notify("Docker client not available", severity="error")
                return

            client = self.docker_client

            if event.button.id == "refresh":
                self.refresh_all()
            elif event.button.id == "start_container":
                if self.selected_container_id:
                    try:
                        container = client.containers.get(self.selected_container_id)
                        container.start()
                        self.notify(f"Started container: {self.selected_container_id[:12]}")
                        self.refresh_all()  # Refresh to show updated status
                    except Exception as e:
                        self.notify(f"Error starting container: {str(e)}", severity="error")
                else:
                    self.notify("Please select a container first", severity="warning")
            elif event.button.id == "stop_container":
                if self.selected_container_id:
                    try:
                        container = client.containers.get(self.selected_container_id)
                        container.stop()
                        self.notify(f"Stopped container: {self.selected_container_id[:12]}")
                        self.refresh_all()  # Refresh to show updated status
                    except Exception as e:
                        self.notify(f"Error stopping container: {str(e)}", severity="error")
                else:
                    self.notify("Please select a container first", severity="warning")
            elif event.button.id == "remove_container":
                if self.selected_container_id:
                    try:
                        container = client.containers.get(self.selected_container_id)
                        container.remove(force=True)
                        self.notify(f"Removed container: {self.selected_container_id[:12]}")
                        self.refresh_all()  # Refresh to show updated list
                    except Exception as e:
                        self.notify(f"Error removing container: {str(e)}", severity="error")
                else:
                    self.notify("Please select a container first", severity="warning")
            elif event.button.id == "pull_image":
                # Get the image name from the input
                try:
                    input_widget = self.query_one("#pull_image_input", Input)
                    image_name = input_widget.value.strip()
                    if image_name:
                        # Start pulling the image
                        self.pull_image_in_background(image_name)
                    else:
                        self.notify("Please enter an image name to pull", severity="warning")
                except:
                    self.notify("Could not access pull input", severity="error")
            elif event.button.id == "remove_image":
                if self.selected_image_id:
                    try:
                        client.images.remove(image=self.selected_image_id)
                        self.notify(f"Removed image: {self.selected_image_id[:12]}")
                        self.refresh_all()  # Refresh to show updated list
                    except Exception as e:
                        self.notify(f"Error removing image: {str(e)}", severity="error")
                else:
                    self.notify("Please select an image first", severity="warning")
        except Exception as e:
            self.notify(f"Error: {str(e)}", severity="error")


def main():
    """Main function to run the TUI"""
    try:
        # Test if Docker is available by creating a client
        docker_client = docker.from_env()
        # Check if we can connect
        docker_client.version()
    except:
        print("Docker is not available. Please make sure Docker is running.")
        sys.exit(1)

    app = DockeroTUI()
    app.run()


if __name__ == "__main__":
    main()