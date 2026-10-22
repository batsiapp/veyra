# MetaTrader 4 under Wine on a virtual screen, for a Linux VPS.
#
# MT4 is a Windows program. This image runs it under Wine on a headless X
# server and shows that screen in a browser through noVNC, so the terminal can
# be installed, logged in, and watched over an SSH tunnel. The Wine prefix
# (MT4 itself, its login, charts and attached EA) lives on a volume.

FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates curl procps \
        wine wine32:i386 wine64 \
        xvfb x11vnc fluxbox novnc websockify supervisor socat \
        fonts-liberation fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1000 --shell /bin/bash trader

ENV DISPLAY=:99 \
    WINEPREFIX=/home/trader/.wine \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    SCREEN_GEOMETRY=1280x800x24 \
    VEYRA_EA_UPSTREAM=veyra:7801

COPY supervisord.conf /etc/veyra-mt4/supervisord.conf
COPY run-terminal.sh install-mt4.sh compile-ea.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/run-terminal.sh /usr/local/bin/install-mt4.sh /usr/local/bin/compile-ea.sh \
    && ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html \
    && mkdir -p /home/trader/.wine && chown trader:trader /home/trader/.wine \
    && mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

USER trader
WORKDIR /home/trader
EXPOSE 6080
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/veyra-mt4/supervisord.conf"]
