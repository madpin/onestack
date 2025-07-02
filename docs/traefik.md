# Traefik: Using Multiple Domains for the Same Service

This guide explains how to configure **two or more domains to point to the same service** using Traefik with Docker. You'll learn how to set up your Docker Compose and Traefik labels, handle SSL certificates, and avoid common pitfalls.

---

## 🛠️ Basic Configuration

To route multiple domains to a single service, use the `||` (OR) operator in your Traefik router rule:

```yaml
services:
  your-service:
    image: your-image
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.your-service.rule=Host(`domain1.com`) || Host(`domain2.com`)"
      - "traefik.http.routers.your-service.entrypoints=websecure"
      - "traefik.http.routers.your-service.tls=true"
```

---

## 🧑‍💻 Complete Example

Here's a practical example routing both `whoami.example.com` and `whoami.traefik-examples.tk` to the same container:

```yaml
whoami:
  image: containous/whoami
  container_name: whoami
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.whoami.rule=Host(`whoami.example.com`) || Host(`whoami.traefik-examples.tk`)"
    - "traefik.http.routers.whoami.entrypoints=web-secure"
    - "traefik.http.routers.whoami.tls=true"
    - "traefik.http.routers.whoami.tls.certresolver=letsencrypt"
```

---

## 🔒 SSL Certificate Considerations

If you're using **Let's Encrypt** for SSL certificates, you may need to specify each domain:

```yaml
labels:
  - "traefik.http.routers.whoami.tls.domains[0].main=example.com"
  - "traefik.http.routers.whoami.tls.domains[1].main=traefik-examples.tk"
```

---

## ✅ Prerequisites

- Both domain names must point to your Traefik instance via DNS
- Traefik must be properly configured and running
- Each domain should have DNS records pointing to your server's IP address

---

## ⚠️ Important Notes

- **Unique router names:** Each service should have a unique router name. Reusing names can cause 404 errors.
- **Host header matching:** Traefik matches requests based on the Host header in the HTTP request.
- **Apply changes:** After editing, run `docker-compose up -d your-service` to apply the new configuration.

---

## ℹ️ Why Use This Approach?

This method lets you serve the same application under multiple domain names with a single service configuration—simple and efficient!

---

## 📚 References

- [Traefik with 2 different services on the same domain](https://community.traefik.io/t/traefik-with-2-different-services-on-the-same-domain/15059)
- [Reddit: 2 different domain names for the same service](https://www.reddit.com/r/Traefik/comments/17uu2s3/how_to_have_2_different_domain_names_for_the_same/)
- [Multiple domains for the same container (frigi.ch)](https://frigi.ch/en/2022/07/multiple-domains-for-the-same-container-with-traefik/)
- [Traefik v2 Docker Compose with multiple domains](https://community.traefik.io/t/traefik-v2-docker-compose-with-multiple-domains/22142)
- [Multiple domains pointing to one Traefik instance](https://community.traefik.io/t/multiple-domains-pointing-to-one-traefik-instance-help/25250)
- [Multiple Traefiks with one domain and one external IP](https://community.traefik.io/t/how-do-i-setup-multiple-traefiks-with-one-domain-and-one-external-ip/20448)
- [Host rule does not support multiple hostnames anymore](https://community.traefik.io/t/host-rule-does-not-support-multiple-hostnames-anymore/21518)
- [Reddit: Multiple domains on a single Docker instance](https://www.reddit.com/r/selfhosted/comments/ivhvap/multiple_domains_on_a_single_docker_instance_w/)
- [StackOverflow: Host rules for multiple domains](https://stackoverflow.com/questions/49895634/traefik-generating-host-rules-for-docker-containers-with-multiple-domains)
- [Multiple domains on one app](https://community.traefik.io/t/multiple-domains-on-one-app/9367)
