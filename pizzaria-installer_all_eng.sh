#!/usr/bin/env bash
# ============================================================
# AUTOMATED INSTALLER - PIZZERIA DEVOPS
# Installs and configures automated deployment of the pizzeria project
# ============================================================

set -euo pipefail  # Fail fast: stop on any error

# Configurations
readonly INSTALL_DIR="/opt/pizzaria"
readonly REPO_URL="https://github.com/rgiovann/devs2blu_devops_projeto_pizzaria.git"
readonly BRANCH="main"
readonly WEB_PORT="8080"
readonly CHANGED_FILE="/tmp/pizzaria-changed"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Log function with timestamp and colors
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")  echo -e "${BLUE}[INFO]${NC} [$timestamp] $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} [$timestamp] $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} [$timestamp] $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} [$timestamp] $message" ;;
    esac
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root"
        log "INFO" "Run: sudo $0"
        exit 1
    fi
    log "SUCCESS" "Running as root"
}

# Install system dependencies
install_system_dependencies() {
    log "INFO" "Updating system repositories..."
    apt-get update -qq

    log "INFO" "Installing dependencies: docker.io, docker-compose, git, curl..."

    # Install essential packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker.io \
        docker-compose \
        git \
        curl \
        ca-certificates \
        gnupg \
        lsb-release \
        util-linux \
        cron

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker

    # Enable cron
    systemctl enable cron
    systemctl start cron

    log "SUCCESS" "Dependencies installed successfully"
}

# Verify Docker is working
verify_docker() {
    log "INFO" "Verifying Docker installation..."

    if ! docker --version >/dev/null 2>&1; then
        log "ERROR" "Docker is not working properly"
        exit 1
    fi

    if ! docker-compose --version >/dev/null 2>&1; then
        log "ERROR" "Docker Compose is not working properly"
        exit 1
    fi

    # Basic Docker test
    if ! docker run --rm hello-world >/dev/null 2>&1; then
        log "ERROR" "Docker cannot run containers"
        exit 1
    fi

    log "SUCCESS" "Docker is configured and working"
}

# Create directory structure
create_directory_structure() {
    log "INFO" "Creating directory structure in $INSTALL_DIR..."

    # Create required directories
    mkdir -p "$INSTALL_DIR"/{scripts,logs,app}

    # Set proper permissions
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR/scripts"
    chmod 755 "$INSTALL_DIR/logs"

    log "SUCCESS" "Directory structure created"
}

# Create configuration file
create_config_file() {
    log "INFO" "Creating configuration file..."

    cat > "$INSTALL_DIR/.env" << EOF
# Automated Deployment Configurations - Pizzeria
REPO_URL=$REPO_URL
BRANCH=$BRANCH
APP_DIR=$INSTALL_DIR/app
WEB_PORT=$WEB_PORT
FORCE_REBUILD=false
INSTALL_DIR=$INSTALL_DIR
CHANGED_FILE=$CHANGED_FILE
EOF

    chmod 644 "$INSTALL_DIR/.env"
    log "SUCCESS" "Configuration file created at $INSTALL_DIR/.env"
}

# Create deploy script
create_deploy_script() {
    log "INFO" "Creating automated deploy script..."

    cat > "$INSTALL_DIR/scripts/deploy.sh" << 'DEPLOY_SCRIPT_EOF'
#!/usr/bin/env bash
# Automated Deployment Script - Pizzeria
set -euo pipefail

# Load configurations
source /opt/pizzaria/.env

# Lock file to avoid concurrent executions
LOCK_FILE="/tmp/pizzaria-deploy.lock"
LOG_FILE="$INSTALL_DIR/logs/deploy.log"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Lock file cleanup
cleanup() {
    rm -f "$LOCK_FILE"
    log "Deploy finished - lock removed"
}
trap cleanup EXIT

# Check if already running
if [[ -f "$LOCK_FILE" ]]; then
    log "Deploy already in progress. Skipping..."
    exit 0
fi

# Create lock
touch "$LOCK_FILE"
log "=== STARTING AUTOMATED DEPLOY ==="

# Function to clone/update repository
update_repository() {
    log "Checking repository..."

    if [[ ! -d "$APP_DIR" ]] || [[ ! -d "$APP_DIR/.git" ]]; then
        log "Cloning repository for the first time..."
        git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"
    else
        log "Updating existing repository..."
        cd "$APP_DIR"

        # Save current hash
        OLD_HASH=$(git rev-parse HEAD 2>/dev/null || echo "none")

        # Force pull (overwrite local changes)
        git fetch origin "$BRANCH"
        git reset --hard "origin/$BRANCH"
        git clean -fd

        # Check for changes
        NEW_HASH=$(git rev-parse HEAD)

        if [[ "$OLD_HASH" != "$NEW_HASH" ]]; then
            log "Changes detected: $OLD_HASH -> $NEW_HASH"
            echo "true" > $CHANGED_FILE
        else
            log "No changes detected"
            echo "false" > $CHANGED_FILE
        fi
    fi
}

# Function to deploy application
deploy_application() {
    cd "$APP_DIR"

	if [[ ! -f "$APP_DIR/docker-compose.yml" ]]; then
		log "ERROR" "docker-compose.yml not found in $APP_DIR"
		exit 1
	fi

	# Check if changes occurred (or force rebuild)
	CHANGED="true"
	if [[ -f "$CHANGED_FILE" ]] && [[ "$FORCE_REBUILD" != "true" ]]; then
		CHANGED=$(cat $CHANGED_FILE)
		# Force deploy if no containers are running (first run)
		if [[ -z "$(docker-compose -f $APP_DIR/docker-compose.yml ps -q)" ]]; then
			log "No containers running, forcing deploy"			
			CHANGED="true"
		fi
	fi

    if [[ "$CHANGED" == "true" ]] || [[ "$FORCE_REBUILD" == "true" ]]; then
        log "Deploying application..."

        # Stop existing containers
        log "Stopping existing containers..."
        docker-compose down --remove-orphans >/dev/null 2>&1 || true

        # Forced rebuild (always rebuild images)
        log "Building images (forced rebuild)..."
        docker-compose build --no-cache --pull

        # Start application
        log "Starting application..."
        docker-compose up -d

        # Wait for containers to be ready
        sleep 15

        # Verify containers are running
        if docker-compose ps | grep -q "Up"; then
            local server_ip=$(hostname -I | awk '{print $1}')
            log " DEPLOY SUCCESSFULLY COMPLETED!"
            log " Application available at: http://$server_ip:$WEB_PORT"
        else
            log " ERROR: Containers did not start correctly"
            docker-compose logs
            exit 1
        fi

        # Clean unused images
        log "Cleaning up unused Docker images..."
        docker image prune -f >/dev/null 2>&1 || true

    else
        log "No changes detected. Deploy not required."
    fi
}

# Main execution
main() {
    log "Checking for updates..."
    update_repository
    deploy_application
    log "=== DEPLOY FINISHED ==="
}

main "$@"
DEPLOY_SCRIPT_EOF

    chmod +x "$INSTALL_DIR/scripts/deploy.sh"
    log "SUCCESS" "Deploy script created at $INSTALL_DIR/scripts/deploy.sh"
}

# Configure crontab
setup_crontab() {
    log "INFO" "Configuring automatic execution (cron every 5 minutes)..."

    # Crontab entry
    local cron_entry="*/5 * * * * $INSTALL_DIR/scripts/deploy.sh >> $INSTALL_DIR/logs/cron.log 2>&1"

    # Check if already exists
    if crontab -l 2>/dev/null | grep -Fq "$INSTALL_DIR/scripts/deploy.sh"; then
        log "INFO" "Crontab already configured"
    else
        # Add entry preserving existing crontab
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        log "SUCCESS" "Crontab configured - execution every 5 minutes"
    fi
}

# Run first deploy
run_initial_deploy() {
    log "INFO" "Running initial deploy..."

    # Run initial deploy
    if "$INSTALL_DIR/scripts/deploy.sh"; then
        log "SUCCESS" "Initial deploy executed successfully"
    else
        log "ERROR" "Initial deploy failed"
        exit 1
    fi
}

# Show final summary
show_summary() {
    local server_ip=$(hostname -I | awk '{print $1}')

    echo
    echo "=============================================="
    echo -e "${GREEN} INSTALLATION COMPLETED SUCCESSFULLY!${NC}"
    echo "=============================================="
    echo -e "${BLUE} Installation directory:${NC} $INSTALL_DIR"
    echo -e "${BLUE} Application URL:${NC} http://$server_ip:$WEB_PORT"
    echo -e "${BLUE} Deploy logs:${NC} $INSTALL_DIR/logs/"
    echo -e "${BLUE} Automatic update:${NC} Every 5 minutes"
    echo -e "${BLUE} Repository:${NC} $REPO_URL"
    echo "=============================================="
    echo
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  • View logs in real time: tail -f $INSTALL_DIR/logs/deploy.log"
    echo "  • Manual deploy: $INSTALL_DIR/scripts/deploy.sh"
    echo "  • View containers: cd $INSTALL_DIR/app && docker-compose ps"
    echo "  • View crontab: crontab -l"
    echo
}

# Main function
main() {
    log "INFO" "Starting installation of automated deploy system..."
	# Clean changes file before starting
	CHANGED_DIR=$(dirname "$CHANGED_FILE")
	if [[ -d "$CHANGED_DIR" ]]; then
		rm -f "$CHANGED_FILE"
		log "Changes file $CHANGED_FILE cleaned"
	else
		log "WARN" "Directory $CHANGED_DIR does not exist, skipping cleanup of $CHANGED_FILE"
	fi
    check_root
    install_system_dependencies
    verify_docker
    create_directory_structure
    create_config_file
    create_deploy_script
    setup_crontab
    run_initial_deploy
    show_summary

    log "SUCCESS" "Installation finished successfully!"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
