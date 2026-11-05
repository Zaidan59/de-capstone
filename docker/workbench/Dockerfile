FROM lscr.io/linuxserver/webtop:ubuntu-xfce
ARG HOP_VERSION=2.19.0
USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg unzip git \
      openjdk-21-jdk maven python3 python3-pip python3-venv python-is-python3 \
      python3-numpy python3-pandas python3-psycopg2 \
      build-essential jq less nano iputils-ping \
    && rm -rf /var/lib/apt/lists/*
# VSCodium upstream apt repository: authentic VSCodium, not VS Code OSS/code-server.
RUN curl -fsSL https://repo.vscodium.dev/vscodium.gpg | gpg --dearmor -o /usr/share/keyrings/vscodium.gpg \
    && curl -fsSL https://repo.vscodium.dev/vscodium.sources -o /etc/apt/sources.list.d/vscodium.sources \
    && apt-get update && apt-get install -y --no-install-recommends codium \
    && rm -rf /var/lib/apt/lists/*
# The official Apache Hop binary client provides Hop GUI and hop-run CLI.
RUN curl -fL --retry 4 \
       "https://downloads.apache.org/hop/${HOP_VERSION}/apache-hop-client-${HOP_VERSION}.zip" \
       -o /tmp/hop.zip \
    && curl -fL --retry 4 \
       "https://downloads.apache.org/hop/${HOP_VERSION}/apache-hop-client-${HOP_VERSION}.zip.sha512" \
       -o /tmp/hop.sha512 \
    && python3 -c 'import hashlib,re; b=open("/tmp/hop.zip","rb").read(); s=open("/tmp/hop.sha512").read(); expect=re.search(r"[0-9a-fA-F]{128}",s).group(0).lower(); actual=hashlib.sha512(b).hexdigest(); assert actual==expect,(actual,expect)' \
    && unzip -q /tmp/hop.zip -d /opt/ \
    && test -f /opt/hop/hop-gui.sh \
    && chmod +x /opt/hop/*.sh \
    && rm -f /tmp/hop.zip /tmp/hop.sha512
# Isolated Python environment for coursework; no system pip modification.
RUN python3 -m venv --system-site-packages /opt/de-python \
    && /opt/de-python/bin/pip install --no-cache-dir \
       'psycopg[binary]>=3.2,<4' 'pymysql>=1.1,<2' 'requests>=2.32,<3' 'sqlalchemy>=2.0,<3' \
    && chmod -R a+rX /opt/de-python /opt/hop
COPY docker/workbench/hop-setup /usr/local/bin/hop-setup
COPY docker/workbench/hop-gui /usr/local/bin/hop-gui
COPY docker/workbench/hop-run /usr/local/bin/hop-run
COPY docker/workbench/hop.desktop /usr/share/applications/apache-hop.desktop
RUN chmod +x /usr/local/bin/hop-gui /usr/local/bin/hop-run /usr/local/bin/hop-setup
ENV PATH="/opt/de-python/bin:${PATH}"
ENV HOP_HOME=/opt/hop
# Do not override Webtop's init/entrypoint: it starts the remote desktop service.

ENV HOP_CONFIG_FOLDER=/config/hop-config
