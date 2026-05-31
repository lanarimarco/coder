FROM ubuntu

RUN apt-get update \
    && apt-get install -y \
    sudo \
    curl \
    && rm -rf /var/lib/apt/lists/*

ARG USER=coder
RUN useradd --groups sudo --no-create-home --shell /bin/bash ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER}

# Bundle extensions into the image — no external download needed at workspace start
COPY extensions/ /opt/coder-extensions/

USER ${USER}
WORKDIR /home/${USER}
