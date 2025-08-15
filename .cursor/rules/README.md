# OneStack Cursor Rules

This directory contains Cursor rules that transform Cursor's AI from a generic code assistant into a project-aware development partner for the OneStack infrastructure.

## Rule Structure

### Core Rules (Always Applied)
- **`000-project-core.mdc`**: Core project context, technology stack, and standards

### Auto-Attaching Rules
- **`100-docker-compose-standards.mdc`**: Docker Compose configuration standards
- **`python-service.mdc`**: Python service development guidelines
- **`shared-services.mdc`**: Shared infrastructure services patterns
- **`traefik-service.mdc`**: Traefik reverse proxy configuration
- **`bash-scripts.mdc`**: Bash script development standards
- **`environment-config.mdc`**: Environment variable management

## How Rules Work

### Always Applied Rules
- `alwaysApply: true` - Included in every AI interaction
- Provides persistent project context and standards

### Auto-Attaching Rules
- `globs: ["pattern"]` - Automatically applied when working with matching files
- Ensures relevant guidance is always available

### Manual Rules
- Can be referenced with `@ruleName` when needed
- Provides specific guidance for particular tasks

## Usage Examples

### Working with Docker Compose
When you open a `docker-compose.yml` file, the Docker Compose standards rule automatically applies, providing guidance on:
- Network configuration
- Traefik integration
- Health checks
- Security best practices

### Python Development
When working in the `python/` directory, the Python service rule automatically applies, helping with:
- Docker image selection
- Port configuration
- Environment variables
- Health checks

### Environment Configuration
When working with `.env` files, the environment configuration rule automatically applies, ensuring:
- Proper variable naming
- Security best practices
- Template structure
- Validation patterns

## Rule Hierarchy

```
.cursor/rules/
├── 000-project-core.mdc          # Always applied
├── 100-docker-compose-standards.mdc  # Auto-attach to docker-compose.yml
├── python-service.mdc            # Auto-attach to python/**/*
├── shared-services.mdc           # Auto-attach to shared/**/*
├── traefik-service.mdc           # Auto-attach to traefik/**/*
├── bash-scripts.mdc              # Auto-attach to *.sh and Makefile
└── environment-config.mdc        # Auto-attach to .env* and config/**/*
```

## Benefits

1. **Consistent Standards**: All team members follow the same patterns
2. **Context Awareness**: AI understands your project structure and conventions
3. **Best Practices**: Built-in guidance for security, performance, and maintainability
4. **Faster Development**: Less time explaining context, more time coding
5. **Quality Assurance**: Automated enforcement of coding standards

## Customization

To add new rules:
1. Create a new `.mdc` file in this directory
2. Add proper frontmatter with description and globs
3. Follow the established pattern and structure
4. Test the rule with relevant files

## Migration from Legacy .cursorrules

The old `.cursorrules` files have been converted to this new structure:
- Root `.cursorrules` → `000-project-core.mdc`
- Service-specific rules → Individual `.mdc` files with appropriate globs
- All rules now have proper frontmatter and organization

This new structure provides better organization, automatic context, and improved AI assistance for your OneStack project.
