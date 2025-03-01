FROM ubuntu:latest

RUN apt-get update && apt-get install -y git jq nodejs npm

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]