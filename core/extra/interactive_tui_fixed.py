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
            raw_containers = self.client.containers.list(all=True)
            self.containers = []
            
            # Clear existing rows
            self.table.clear()
            
            for container in raw_containers:
                container_info = ContainerInfo(
                    id=container.short_id,
                    name=container.name,
                    image=container.image.tags[0] if container.image.tags else "<none>",
                    status=container.status,
                    ports="",
                    command=container.attrs.get("Config", {}).get("Cmd", [""])[0] if container.attrs.get("Config", {}).get("Cmd") else ""
                )
                self.containers.append(container_info)
                
                status_color = "green" if "running" in container.status.lower() else "red"
                self.table.add_row(
                    container_info.id,
                    container_info.name,
                    container_info.image,
                    f"[{status_color}]{container_info.status}[/{status_color}]",
                    container_info.command[:50] + "..." if len(container_info.command) > 50 else container_info.command
                )
        except Exception as e:
            print(f"Error refreshing containers: {e}")
    
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
            raw_images = self.client.images.list()
            self.images = []
            
            # Clear existing rows
            self.table.clear()
            
            for image in raw_images:
                for tag in image.tags:
                    repo, tag_name = tag.split(':') if ':' in tag else (tag, 'latest')
                    image_info = ImageInfo(
                        id=image.short_id.replace('sha256:', '')[:12],
                        repository=repo,
                        tag=tag_name,
                        size=f"{image.attrs['Size'] / (1024*1024):.1f}MB"
                    )
                    self.images.append(image_info)
                    self.table.add_row(
                        image_info.id,
                        image_info.repository,
                        image_info.tag,
                        image_info.size
                    )
        except Exception as e:
            print(f"Error refreshing images: {e}")
    
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
        yield Button("Remove Image", id="remove_image", variant="error")
        yield Button("Refresh", id="refresh", variant="default")
        
        yield Label("\n[b]DockerHub Search:[/b]", id="search-title")
        yield DockerHubSearchInput()
        
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
            client = docker.from_env()
            containers = client.containers.list(all=True)
            running = len(client.containers.list(filters={'status': 'running'}))
            images = len(client.images.list())
            
            stats_text = f"Containers: Total={len(containers)}, Running={running}\nImages: {images}"
            self.query_one("#stats_label", Label).update(stats_text)
        except Exception as e:
            self.query_one("#stats_label", Label).update(f"Error getting stats: {e}")


class DockeroTUI(App):
    """Main application for the Dockero TUI"""
    
    BINDINGS = [
        ("q", "quit", "Quit"),
        ("r", "refresh", "Refresh"),
        ("tab", "focus_next", "Focus Next Widget"),
    ]
    
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
    
    #search-title {
        text-style: bold;
        color: $accent;
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
    
    def handle_dockerhub_search(self, search_term: str):
        """Handle DockerHub search for images"""
        if len(search_term) >= 3:  # Only search if at least 3 characters
            try:
                # This is a simplified approach - in a full implementation, 
                # we would actually query the DockerHub API
                self.notify(f"Searching DockerHub for: {search_term}")
                # For demo purposes, could implement actual search here
            except Exception as e:
                self.notify(f"Search error: {str(e)}", severity="error")
    
    def refresh_all(self):
        """Refresh all panels"""
        try:
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
        except Exception as e:
            print(f"Error in refresh_all: {e}")
    
    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press events"""
        try:
            client = docker.from_env()
            
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
    if not os.getenv("DOCKER_HOST") and not os.path.exists("/var/run/docker.sock"):
        print("Docker is not available. Please make sure Docker is running.")
        sys.exit(1)
    
    app = DockeroTUI()
    app.run()


if __name__ == "__main__":
    main()