# OneStack Makefile
# Provides convenient targets for managing the Docker stack

.PHONY: help network up down clean logs status create-tool create-shared logs-% restart restartf logsf

# Default target
help:
	@echo "OneStack Management Commands:"
	@echo ""
	@echo "  make network                  - Create all networks defined in .env files."
	@echo "  make up [service]             - Start all services or a specific [service]."
	@echo "  make down [service]           - Stop all services or a specific [service]."
	@echo "  make restart [service]        - Restart all services or a specific [service]."
	@echo "  make clean [ARGS...]          - Stop services and clean resources. Use ARGS for options (e.g., make clean ARGS=--all-volumes)."
	@echo "  make logs [service] [ARGS...] - Show logs for all or a specific [service]. Use ARGS for options (e.g., make logs traefik ARGS=\"-f --tail 50\")."
	@echo "  make logs-SERVICE [ARGS...]   - Shortcut to show logs for SERVICE (e.g., make logs-traefik ARGS=-f)."
	@echo "  make logsf SERVICE            - Shortcut to follow logs for SERVICE (e.g., make logsf traefik)."
	@echo "  make status                   - Show status of all services."
	@echo ""
	@echo "  make create-tool NAME=...     - Create a new tool template (e.g., make create-tool NAME=mytool)."
	@echo "  make create-shared NAME=...   - Create a new shared service template (e.g., make create-shared NAME=mydb)."
	@echo ""
	@echo "Notes:"
	@echo "  - [service] argument is the name of the service directory (e.g., traefik, homepage)."
	@echo "  - ARGS are passed directly to the underlying 'onestack.sh' script commands."
	@echo "  - To load environment variables into your current shell (e.g., for direct Docker CLI use),"
	@echo "    source the .env file directly: 'source .env' or 'source <service>/.env'."
	@echo ""
	@echo "Examples:"
	@echo "  make up                          # Start all services."
	@echo "  make up traefik                  # Start only Traefik."
	@echo "  make down                        # Stop all services."
	@echo "  make restart homepage            # Restart only Homepage."
	@echo "  make logs                        # Show logs from all services."
	@echo "  make logs ARGS='-f --tail 100'   # Follow logs from all services, showing last 100 lines."
	@echo "  make logs traefik ARGS='-f'      # Follow logs for Traefik."
	@echo "  make logs-postgres ARGS='-f'     # Follow logs for Postgres (shortcut)."
	@echo "  make logsf homepage              # Follow logs for Homepage (shortcut)."
	@echo "  make clean ARGS='--all-volumes'  # Clean, including all unused Docker volumes."
	@echo "  make create-tool NAME=grafana    # Create a new tool folder 'grafana'."
	@echo ""

# Create networks defined in .env files
network:
	@bash ./bash/onestack.sh network

# Start all services or a specific one. Pass service name as argument.
# Example: make up traefik
up:
	@bash ./bash/onestack.sh up $(filter-out $@,$(MAKECMDGOALS))

# Stop all services or a specific one. Pass service name as argument.
# Example: make down traefik
down:
	@bash ./bash/onestack.sh down $(filter-out $@,$(MAKECMDGOALS))

# Clean up: stop services and remove networks/resources. ARGS are passed to onestack.sh clean command.
# Example: make clean ARGS=--all-volumes
clean:
	@bash ./bash/onestack.sh clean $(ARGS)

# Show logs from all services or a specific one. Pass service name and ARGS.
# Examples:
#   make logs
#   make logs traefik
#   make logs ARGS="-f --tail 10"
#   make logs traefik ARGS="-f --tail 20"
logs:
	@bash ./bash/onestack.sh logs $(filter-out $@,$(MAKECMDGOALS)) $(ARGS)

# Shortcut to show logs from specific service. ARGS are passed.
# Example: make logs-postgres ARGS="-f"
logs-%:
	@bash ./bash/onestack.sh logs $* $(ARGS)

# Shortcut to follow logs from a specific service.
# Example: make logsf litellm
logsf:
	@bash ./bash/onestack.sh logs $(filter-out $@,$(MAKECMDGOALS)) -f

# Show status of all services
status:
	@bash ./bash/onestack.sh status

# Create a new tool. NAME=<tool-name>
create-tool:
	@bash ./bash/create-tool.sh $(NAME)

# Create a new shared service. NAME=<service-name>
create-shared:
	@bash ./bash/create-shared.sh $(NAME)

# Restart all services or a specific one. Pass service name as argument.
# Example: make restart traefik
restart:
	@bash ./bash/onestack.sh restart $(filter-out $@,$(MAKECMDGOALS))

# Restart a service and then follow its logs.
# Example: make restartf litellm
restartf:
	$(MAKE) restart $(filter-out $@,$(MAKECMDGOALS)) && $(MAKE) logsf $(filter-out $@,$(MAKECMDGOALS))

# Reload all .env files and export to current shell
# This target is removed as reload.sh needs to be sourced.
# Instruct users to source .env files manually if needed for current shell:
# e.g., source .env
# reload:
#	@echo "To reload environment variables into your current shell, please use: source .env"
#	@echo "Or source specific .env files as needed."


