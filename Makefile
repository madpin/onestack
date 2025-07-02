# OneStack Makefile
# Provides convenient targets for managing the Docker stack

.PHONY: help network up down clean logs status create-tool create-shared logs-% reload

# Default target
help:
	@echo "OneStack Management Commands:"
	@echo ""
	@echo "  make network        - Create all networks from .env files"
	@echo "  make up             - Start all discovered Docker services"
	@echo "  make down           - Stop all discovered Docker services"
	@echo "  make clean          - Stop services and clean up networks/resources"
	@echo "  make logs           - Show logs from all services (use ARGS for options)"
	@echo "  make logs-SERVICE   - Show logs from specific service (e.g., make logs-postgres)"
	@echo "  make status         - Show status of all services"
	@echo ""
	@echo "  make create-tool    - Create a new tool (NAME=tool-name)"
	@echo "  make create-shared  - Create a new shared service (NAME=service-name)"
	@echo ""
	@echo "Examples:"
	@echo "  make logs                        # Show logs from all services"
	@echo "  make logs ARGS='-f'              # Follow logs from all services"
	@echo "  make logs SERVICE=postgres       # Show logs for postgres service only"
	@echo "  make logs SERVICE=postgres ARGS='-f' # Follow logs for postgres service"
	@echo "  make logs-postgres               # Show logs for postgres service"
	@echo "  make logs-traefik ARGS='-f'      # Follow logs for traefik service"
	@echo "  make logs ARGS='-s traefik'      # Show logs for traefik service (alternative)"
	@echo "  make logs ARGS='-t 50 -f'        # Follow last 50 lines from all services"
	@echo "  make create-tool NAME=grafana    # Create a new tool called grafana"
	@echo "  make create-shared NAME=mongodb  # Create a new shared service called mongodb"
	@echo ""

# Create networks (discovers all .env files and networks)
network:
	@bash ./bash/network.sh

# Start all services or a specific one (discovers all docker-compose files)
up:
	@bash ./bash/up.sh $(filter-out $@,$(MAKECMDGOALS))

# Stop all services or a specific one (discovers all docker-compose files)
down:
	@bash ./bash/down.sh $(filter-out $@,$(MAKECMDGOALS))

# Clean up: stop services and remove networks/resources
clean:
	@bash ./bash/clean.sh

# Show logs from all services with optional arguments or a service name
logs:
ifeq (,$(word 2,$(MAKECMDGOALS)))
	@bash ./bash/logs.sh $(ARGS)
else
	@bash ./bash/logs.sh -s $(word 2,$(MAKECMDGOALS)) $(ARGS)
endif

# Show logs from specific service (e.g., make logs-postgres)
logs-%:
	@bash ./bash/logs.sh -s $* $(ARGS)

# Show and follow logs from a specific service (e.g., make logsf litellm)
logsf:
	@bash ./bash/logs.sh -s $(filter-out $@,$(MAKECMDGOALS)) -f

# Show status of all services
status:
	@bash ./bash/status.sh

# Create a new tool
create-tool:
	@bash ./bash/create-tool.sh $(NAME)

# Create a new shared service
create-shared:
	@bash ./bash/create-shared.sh $(NAME)

# Restart all services (down then up)
restart:
	@bash ./bash/restart.sh $(filter-out $@,$(MAKECMDGOALS))

# Restart a service and follow its logs (e.g., make restartf litellm)
restartf:
	$(MAKE) restart $(filter-out $@,$(MAKECMDGOALS)) && $(MAKE) logsf $(filter-out $@,$(MAKECMDGOALS))

# Reload all .env files and export to current shell
reload:
	@bash ./bash/reload.sh


