# dbgate:

```
version: '3'

services:
  dbgate:
    image: dbgate/dbgate
    restart: always
    ports:
      - 8080:3000  # Optional: remove if only using Traefik
    volumes:
      - ./data:/root/.dbgate
      - ./config:/app/config
    environment:
      CONNECTIONS: mypg
      LABEL_mypg: MyPostgres
      SERVER_mypg: postgres
      USER_mypg: postgres
      PASSWORD_mypg: password
      PORT_mypg: 5432
      ENGINE_mypg: postgres@dbgate-plugin-postgres
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dbgate.rule=Host(`dbgate.example.com`)"
      - "traefik.http.routers.dbgate.entrypoints=websecure"
      - "traefik.http.routers.dbgate.tls=true"
      - "traefik.http.services.dbgate.loadbalancer.server.port=3000"

# No need to declare volumes if using bind mounts (./data, ./config)

```