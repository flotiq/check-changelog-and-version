FROM ubuntu:latest

RUN apt-get update && apt-get install -y git jq nodejs npm

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

# Create a runner user and group
RUN groupadd -r runner && useradd -m -r -g runner runner

# Change ownership of /app to runner
RUN chown runner:runner /app
#Change ownership of the script.
RUN chown runner:runner /app/entrypoint.sh

USER runner

ENTRYPOINT ["/app/entrypoint.sh"]