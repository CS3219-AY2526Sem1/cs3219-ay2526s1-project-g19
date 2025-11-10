FROM confluentinc/cp-kafka:7.5.0

USER root

# Add custom entrypoint that handles KRaft storage formatting
COPY --chmod=755 entrypoint.sh /usr/local/bin/

# Switch back to appuser
USER appuser

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
