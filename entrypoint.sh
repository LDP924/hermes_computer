#!/bin/bash

start_services() {
    echo "[*] 启动服务..."
    export USER="${USER:-root}"
    export HOME="${HOME:-/root}"
    export DISPLAY=":1"
    export PATH="/root/.local/bin:/usr/local/node/bin:/root/.hermes/hermes-agent/venv/bin:$PATH"

    VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
    VNC_DEPTH="${VNC_DEPTH:-24}"
    VNC_PORT=5901
    NOVNC_PORT=7860
    NOVNC_PATH="/usr/share/novnc"

    # ── VNC 密码配置 ──────────────────────────────────────────
    if [ -n "${VNC_PASSWD}" ]; then
        mkdir -p "${HOME}/.vnc"
        echo "${VNC_PASSWD}" | /usr/bin/vncpasswd -f > "${HOME}/.vnc/passwd"
        chmod 600 "${HOME}/.vnc/passwd"
        VNC_SECURITY_ARGS="-SecurityTypes VncAuth"
        VNC_AUTH_ARGS="-rfbauth ${HOME}/.vnc/passwd"
    else
        VNC_SECURITY_ARGS="-SecurityTypes None --I-KNOW-THIS-IS-INSECURE"
        VNC_AUTH_ARGS=""
    fi

    # 清理残留锁文件（Docker 重启场景）
    vncserver -kill "${DISPLAY}" 2>/dev/null || true
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

    # ── 启动 TigerVNC ────────────────────────────────────────
    echo "[*] 启动 TigerVNC on ${DISPLAY} (${VNC_GEOMETRY})..."
    vncserver "${DISPLAY}" \
        -geometry "${VNC_GEOMETRY}" \
        -depth "${VNC_DEPTH}" \
        $VNC_SECURITY_ARGS \
        $VNC_AUTH_ARGS \
        -localhost no \
        -fg \
        $DEMO_ARGS &

    # 等待 VNC 端口就绪（最多 30s）
    echo "[*] 等待 VNC 就绪（端口 ${VNC_PORT}）..."
    for i in $(seq 1 30); do
        if ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT}" || \
           netstat -tlnp 2>/dev/null | grep -q ":${VNC_PORT}"; then
            echo "[✓] VNC 已就绪"
            break
        fi
        sleep 1
    done

    # 继承 dbus 环境（xstartup 写入的）
    source /tmp/dbus-session.env 2>/dev/null || true
    export DBUS_SESSION_BUS_ADDRESS

    # Xfce4 桌面环境变量
    export XDG_CURRENT_DESKTOP=XFCE
    export XDG_SESSION_TYPE=x11
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
    export INPUT_METHOD=fcitx
    export SDL_IM_MODULE=fcitx

    mkdir -p /tmp/root-runtime
    chmod 700 /tmp/root-runtime
    export XDG_RUNTIME_DIR=/tmp/root-runtime

    # Demo 模式壁纸
    if [[ "$(hostname)" == *"-ldp924-"* ]]; then
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/last-image -s /usr/share/xfce4/backdrops/xfce-verticals.png 2>/dev/null || true
        rm -rf /mnt/workspace/root 2>/dev/null || true
    fi

    # ── 启动 noVNC ───────────────────────────────────────────
    echo "[*] 启动 noVNC，监听端口 ${NOVNC_PORT}..."

    cat > "${NOVNC_PATH}/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&reconnect=true&reconnect_delay=2000&resize=remote&view_only=false&quality=6&compression=2&show_dot=false">
    <title>正在连接桌面...</title>
    <style>
        body{background:#1a1a2e;color:#cdd6f4;font-family:sans-serif; display:flex;align-items:center;justify-content:center; height:100vh;margin:0;flex-direction:column;gap:12px;}
        .spinner{width:40px;height:40px;border:4px solid #313244; border-top-color:#89b4fa;border-radius:50%;animation:spin 0.8s linear infinite;}
        @keyframes spin{to{transform:rotate(360deg)}}
    </style>
</head>
<body>
    <div class="spinner"></div>
    <p>⏳ 正在连接远程桌面...</p>
