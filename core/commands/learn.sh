#!/usr/bin/env bash

learn() {
    local subcommand="${args[1]}"
    
    if [[ -z "$subcommand" ]] || [[ "$subcommand" != "start" && "$subcommand" != "basic" && "$subcommand" != "intermediate" && "$subcommand" != "advanced" && "$subcommand" != "docker" && "$subcommand" != "concepts" && "$subcommand" != "examples" ]]; then
        log.hint "learn <start|basic|intermediate|advanced|docker|concepts|examples> [topic]"
        return 1
    fi
    
    case "$subcommand" in
        "start"|"basic")
            learn_basic "${args[2]}"
            ;;
        "intermediate")
            learn_intermediate "${args[2]}"
            ;;
        "advanced")
            learn_advanced "${args[2]}"
            ;;
        "docker")
            learn_docker_fundamentals "${args[2]}"
            ;;
        "concepts")
            learn_concepts "${args[2]}"
            ;;
        "examples")
            learn_examples "${args[2]}"
            ;;
        *)
            log.error "Unknown learn subcommand: $subcommand"
            return 1
            ;;
    esac
}

explain() {
    local command_to_explain="$1"
    
    if [[ -z "$command_to_explain" ]]; then
        log.hint "explain <command> [subcommand]"
        log.sub "Shows what a Dockero command does and the equivalent Docker commands"
        return 1
    fi
    
    log.setline "Command Explanation"
    
    case "$command_to_explain" in
        "run")
            cat << EOF
🔹 dockero run <name> [image]
   • Purpose: Start an existing container or create a new one
   • What happens: 
     1. Checks if container named '<name>' exists
     2. If exists: starts the container and attaches interactively
     3. If not exists: creates new container from image and runs it
   • Equivalent Docker: 
     docker start -ai <name>  (if container exists)
     docker run -it [default volumes/ports] --name <name> <image>
   • Learn more: dockero learn docker containers
EOF
            ;;
        "setup")
            cat << EOF
🔹 dockero setup <project-path>
   • Purpose: Set up a containerized development environment for a project
   • What happens:
     1. Finds .dockero configuration in project directory
     2. Parses configuration for image, volumes, ports, etc.
     3. Pulls image if needed
     4. Runs container with specified configuration
   • Equivalent Docker: 
     docker run -it [config from .dockero file] 
   • Learn more: dockero learn concepts volumes && dockero learn concepts networks
EOF
            ;;
        "compose")
            cat << EOF
🔹 dockero compose up
   • Purpose: Start multi-container applications defined in .dockero-compose
   • What happens:
     1. Reads .dockero-compose file for service definitions
     2. Resolves dependencies between services
     3. Creates and starts all defined services
   • Equivalent Docker: 
     docker-compose up  or  docker run with dependencies managed manually
   • Learn more: dockero learn concepts multi-container
EOF
            ;;
        *)
            log.info "Explanation for command: $command_to_explain"
            log.sub "This command provides functionality for Docker container management."
            log.sub "To see detailed explanation, check dockero learn concepts for related topics."
            ;;
    esac
}

learn_basic() {
    local topic="$1"
    log.setline "Docker Basics Learning"
    
    case "$topic" in
        "containers"|"container")
            cat << EOF
🎯 Docker Containers - The Basics

Containers are isolated, lightweight environments that package an application 
and its dependencies together.

🔹 Container vs Image:
   • Image = Blueprint/template (like a class in programming)
   • Container = Running instance of an image (like an object)

🔹 Container lifecycle:
   1. CREATE: Container is created from an image
   2. START: Container begins running
   3. STOP: Container stops running
   4. DELETE: Container is removed (but image remains)

🔹 In Dockero:
   • dockero run <name> <image>  → Create and start a container
   • dockero start <name>        → Start stopped container
   • dockero stop <name>         → Stop running container
   • dockero remove <name>       → Delete container

💡 Think of containers like virtual machines but much lighter and faster!
EOF
            ;;
        "images")
            cat << EOF
🎯 Docker Images - The Building Blocks

Images are packaged applications with all their dependencies.

🔹 What's in an image:
   • Base operating system
   • Application files
   • Dependencies and libraries
   • Configuration files

🔹 Common image formats:
   • ubuntu:20.04      → Ubuntu OS, version 20.04
   • nginx:latest      → NGINX web server, latest version
   • node:16-alpine    → Node.js version 16 on Alpine Linux

🔹 In Dockero:
   • Images are automatically pulled when needed
   • You specify images in .dockero files or run commands
   • dockero list -img  → See all available images

💡 Images are like templates - they don't do anything until you run them as containers!
EOF
            ;;
        "volumes")
            cat << EOF
🎯 Docker Volumes - Persistent Data

Volumes connect container file systems to host file systems.

🔹 Why volumes matter:
   • Containers are temporary - when deleted, data is lost
   • Volumes keep data even when containers stop/are removed
   • Share files between host and container

🔹 Volume format:  host_path:container_path
   • Example: ./src:/app/src  → Host ./src maps to container /app/src

🔹 In Dockero:
   • Setup command uses: -v /path/to/project:/workspace
   • Sync command manages file transfers
   • .dockero config has 'env' parameter for volumes

💡 Volumes are like shared folders between your computer and the container!
EOF
            ;;
        "")
            cat << EOF
🎯 Docker Basics - Getting Started

Welcome to Docker learning with Dockero! Here are key concepts:

🔹 Containers: Isolated environments for running applications
   • Like a lightweight virtual machine
   • Start instantly and use fewer resources

🔹 Images: Templates for containers
   • Downloaded from registries (like Docker Hub)
   • Example: ubuntu, nginx, postgres

🔹 Volumes: Connect container files to host files
   • Essential for development and data persistence

🔹 Networks: Connect containers together
   • Allow containers to communicate

To learn more about specific topics:
  • dockero learn basic containers
  • dockero learn basic images  
  • dockero learn basic volumes
  • dockero learn concepts  (for all concepts)

Try your first container:
  dockero run hello-world ubuntu:latest
EOF
            ;;
        *)
            log.info "Unknown basic topic: $topic"
            log.sub "Available topics: containers, images, volumes"
            ;;
    esac
}

learn_intermediate() {
    local topic="$1"
    log.setline "Docker Intermediate Learning"
    
    case "$topic" in
        "networks"|"network")
            cat << EOF
🎯 Docker Networks - Connecting Containers

Networks allow containers to communicate with each other and the host.

🔹 Built-in networks:
   • bridge: Default network, containers get internal IPs
   • host: Container uses host's network directly
   • none: Container has no network access

🔹 Custom networks:
   • docker network create mynetwork
   • Containers on same network can reach each other by name

🔹 In Dockero:
   • dockero net new <name>     → Create custom network
   • dockero net add <c> <n>    → Connect container to network
   • dockero net list           → See all networks

🔹 Common scenario:
   Web container needs to talk to database container
   Both on same custom network, can connect using container name
EOF
            ;;
        "environment"|"env")
            cat << EOF
🎯 Environment Variables - Configuration

Environment variables pass configuration to containers.

🔹 Setting variables:
   • In .dockero file: [default] section
   • Command line: docker run -e VAR=value
   • In compose files: environment parameter

🔹 Common environment variables:
   • PORT=3000           → Application runs on port 3000
   • DATABASE_URL=...    → Connection string for database
   • NODE_ENV=production → Node.js environment

🔹 In Dockero:
   • Compose files support environment lists
   • dockero env command manages different environments
   • Configuration files can set environment variables

💡 Environment variables are like command-line arguments for containers!
EOF
            ;;
        "")
            cat << EOF
🎯 Docker Intermediate Concepts

Now that you know the basics, let's explore more advanced concepts:

🔹 Networks: Connect containers together
   • dockero net commands manage networks
   • Essential for multi-container applications

🔹 Environment Variables: Configure applications
   • Pass settings without changing code
   • Different values for dev vs production

🔹 Multi-container: Applications with multiple services
   • Web server + database + cache
   • Managed with compose functionality

To learn more:
  • dockero learn intermediate networks
  • dockero learn intermediate env
  • dockero learn advanced for more topics
EOF
            ;;
        *)
            log.info "Unknown intermediate topic: $topic"
            log.sub "Available topics: networks, env"
            ;;
    esac
}

learn_advanced() {
    local topic="$1"
    log.setline "Docker Advanced Learning"
    
    case "$topic" in
        "security")
            cat << EOF
🎯 Docker Security - Safe Container Usage

Container security is critical for production applications.

🔹 Security best practices:
   • Don't run as root unnecessarily (use --user flag)
   • Drop unnecessary capabilities
   • Read-only root filesystem when possible
   • Limit resources (memory, CPU)
   • Scan images for vulnerabilities

🔹 In Dockero:
   • Security options available through configuration
   • Use minimal base images for better security
   • Run containers as non-root users when possible

🔹 Common security measures:
   • docker run --read-only --user 1000:1000
   • docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE
   • docker run --memory=512m --cpus=0.5
EOF
            ;;
        "")
            cat << EOF
🎯 Docker Advanced Topics

For experienced users looking to optimize their Docker usage:

🔹 Security: Running containers safely
   • Minimize privileges and capabilities
   • Scan images for vulnerabilities

🔹 Optimization: Resource management
   • Memory and CPU limits
   • Multi-stage builds

🔹 Production: Running in real environments
   • Health checks and monitoring
   • Service discovery and load balancing
   • Backup and recovery

To learn specific advanced topics:
  • dockero learn advanced security
  • dockero learn concepts for comprehensive guides
EOF
            ;;
        *)
            log.info "Unknown advanced topic: $topic"
            log.sub "Available topics: security"
            ;;
    esac
}

learn_docker_fundamentals() {
    local topic="$1"
    log.setline "Docker Fundamentals"
    
    cat << EOF
🏛️  Docker Architecture and Fundamentals

Docker follows a client-server architecture:

🔹 Docker Client: Command-line tool (docker) that sends commands
🔹 Docker Server (Daemon): Runs containers, manages images
🔹 Docker Objects: Images, containers, networks, volumes

🔹 Dockerfile: Instructions to build custom images
   • FROM: Base image
   • COPY: Add files to image  
   • CMD: Default command to run

🔹 Docker Registry: Store and share images
   • Docker Hub: Public registry
   • Private registries: Company-specific

💡 Dockero simplifies these concepts but understanding fundamentals helps with troubleshooting!

Common Docker commands (what Dockero uses behind the scenes):
  • docker run      → Create and start container
  • docker ps       → List running containers
  • docker images   → List available images
  • docker logs     → View container logs
EOF
}

learn_concepts() {
    local topic="$1"
    log.setline "Docker Concepts Guide"
    
    case "$topic" in
        "multi-container"|"multi")
            cat << EOF
🔗 Multi-Container Applications

Real applications often need multiple services working together:

Example: Modern web application
  • Web server (nginx, apache)
  • Application server (node.js, python, java)
  • Database (postgres, mysql, redis)
  • Message queue (rabbitmq, kafka)

🔹 Docker Compose: Standard way to define multi-container apps
   • Single file defines all services
   • Handles networking between services
   • Manages startup order with dependencies

🔹 In Dockero:
   • dockero compose implements this functionality
   • .dockero-compose file defines services
   • Services can communicate using service names

🔹 Common patterns:
   • frontend-service → connects to → backend-service
   • all-services → connect to → database-service
EOF
            ;;
        "lifecycle")
            cat << EOF
🔄 Container Lifecycle Management

Containers have a specific lifecycle:

CREATED → STARTED → RUNNING → STOPPED → DELETED

🔹 Lifecycle commands:
   • CREATE:   docker create / dockero run (new container)
   • START:    docker start / dockero start
   • RUNNING:  container is active
   • STOP:     docker stop / dockero stop  
   • DELETE:   docker rm / dockero remove

🔹 State management:
   • Exited containers still exist but aren't running
   • Can be started again (dockero start)
   • Deleted when no longer needed (dockero remove)

🔹 Best practices:
   • Stop gracefully before deleting
   • Use restart policies for production
   • Monitor container health
EOF
            ;;
        "")
            cat << EOF
📚 Docker Core Concepts

Key Docker concepts for all developers:

🔹 Container: Running instance of an image
   • Lightweight, isolated environment
   • Can be started, stopped, deleted

🔹 Image: Packaged application + dependencies  
   • Immutable template for containers
   • Downloaded from registries

🔹 Volume: Persistent file storage
   • Connects host and container filesystems
   • Survives container restarts/deletion

🔹 Network: Container communication
   • Internal container network
   • External port publishing

🔹 Registry: Image storage and sharing
   • Centralized image repository
   • Public and private options

To dive deeper into concepts:
  • dockero learn concepts multi-container
  • dockero learn concepts lifecycle
  • dockero learn docker for fundamentals
EOF
            ;;
        *)
            log.info "Unknown concept topic: $topic"
            log.sub "Available topics: multi-container, lifecycle"
            ;;
    esac
}

learn_examples() {
    local topic="$1"
    log.setline "Docker Learning Examples"
    
    case "$topic" in
        "web-app")
            cat << EOF
🌐 Web Application Example

Let's build a simple web application with Dockero:

1. Create project directory:
   mkdir my-web-app && cd my-web-app

2. Create a simple web server (app.js for Node.js):
   console.log("Server running on port 3000");
   // Simple server code here

3. Create .dockero file:
   [default]
   name = my-web-app
   image = node:16-alpine
   command = node app.js
   restart_policy = always

   [volumes]
   env = .:/app
   port = 3000:3000

4. Run with Dockero:
   dockero setup .

This creates a Node.js container that:
   • Runs your app.js file
   • Maps port 3000 from container to host
   • Automatically restarts if it crashes
   • Syncs current directory to /app in container
EOF
            ;;
        "database")
            cat << EOF
💾 Database Example

Running a database with data persistence:

1. Create project directory:
   mkdir my-db-app && cd my-db-app

2. Create .dockero-compose file:
   [service:db]
   container_name = myapp-db
   image = postgres:13
   environment = POSTGRES_DB=myapp,POSTGRES_USER=user,POSTGRES_PASSWORD=password
   volumes = ./data:/var/lib/postgresql/data
   ports = 5432:5432
   
   [service:app] 
   container_name = myapp-web
   image = node:16-alpine
   volumes = .:/app
   command = npm start
   depends_on = db

3. Start services:
   dockero compose up

This creates:
   • PostgreSQL database with persistent data storage
   • Application container that depends on the database
   • Automatic startup order (db before app)
EOF
            ;;
        "")
            cat << EOF
🎯 Learning by Examples

Practical examples to help you get started:

🔹 Web Application: Simple server with port mapping
   • dockero learn examples web-app

🔹 Database Setup: Persistent data container
   • dockero learn examples database

🔹 Multi-Service: Web app with database
   • dockero learn examples web-app && dockero learn examples database

Each example shows how to:
  1. Structure your project
  2. Configure Dockero files
  3. Run and manage containers
  4. Connect services together
EOF
            ;;
        *)
            log.info "Unknown example topic: $d"
            log.sub "Available topics: web-app, database"
            ;;
    esac
}