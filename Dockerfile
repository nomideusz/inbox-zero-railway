# Inbox Zero, pinned to an upstream main-branch build (upstream tags images by commit SHA).
FROM ghcr.io/elie222/inbox-zero:0fabe52
COPY railway-entrypoint.sh /app/docker/scripts/railway-entrypoint.sh
RUN chmod +x /app/docker/scripts/railway-entrypoint.sh
# CMD, not ENTRYPOINT: the base image's docker-entrypoint.sh stays in front.
CMD ["/app/docker/scripts/railway-entrypoint.sh"]
