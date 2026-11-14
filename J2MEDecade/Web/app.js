/**
 * J2ME Decade iOS - Client Controller & Multi-Tab Manager
 * KamenRider Decade J2ME Engine (Audio Removed per user requirement)
 */

(function () {
    'use strict';

    // Key mapping to standard J2ME Canvas KeyCodes
    const KEY_MAP = {
        'SOFT_LEFT': -6,
        'SOFT_RIGHT': -7,
        'UP': -1,
        'DOWN': -2,
        'LEFT': -3,
        'RIGHT': -4,
        'FIRE': -5,
        'CALL': -10,
        'END': -11,
        '1': 49, '2': 50, '3': 51,
        '4': 52, '5': 53, '6': 54,
        '7': 55, '8': 56, '9': 57,
        'STAR': 42, '0': 48, 'HASH': 35
    };

    // Slot Manager (Multi-Tab / Multi-Session)
    const SlotManager = {
        slots: {},
        activeSlotId: 1,
        nextSlotId: 2,

        init() {
            this.slots[1] = {
                id: 1,
                name: 'Tab 1',
                running: false,
                jarBlob: null,
                server: { host: '112.213.94.135', port: 14444, override: false },
                proxy: { type: 'DIRECT', host: '', port: 0 }
            };
            this.bindEvents();
            this.updateHUD();
            this.showPlaceholder();
        },

        getActiveSlot() {
            return this.slots[this.activeSlotId] || this.slots[1];
        },

        addSlot() {
            const id = this.nextSlotId++;
            this.slots[id] = {
                id: id,
                name: `Tab ${id}`,
                running: false,
                jarBlob: null,
                server: { host: '112.213.94.135', port: 14444, override: false },
                proxy: { type: 'DIRECT', host: '', port: 0 }
            };

            const tabItem = document.createElement('div');
            tabItem.className = 'tab-item';
            tabItem.dataset.slot = id;
            tabItem.innerHTML = `
                <span class="tab-title">Tab ${id}</span>
                <button class="tab-close" data-slot="${id}">&times;</button>
            `;
            document.getElementById('tabs-scroll').appendChild(tabItem);

            this.switchSlot(id);
        },

        switchSlot(slotId) {
            if (!this.slots[slotId]) return;
            this.activeSlotId = slotId;

            // Update UI tabs
            document.querySelectorAll('.tab-item').forEach(tab => {
                tab.classList.toggle('active', parseInt(tab.dataset.slot) === slotId);
            });

            // Update Decade Engine VM context
            if (window.js2me) {
                window.js2me.currentVM = slotId;
            }

            this.updateHUD();
        },

        closeSlot(slotId) {
            if (Object.keys(this.slots).length <= 1) {
                alert('Phải giữ lại ít nhất 1 tab!');
                return;
            }

            delete this.slots[slotId];
            const tabEl = document.querySelector(`.tab-item[data-slot="${slotId}"]`);
            if (tabEl) tabEl.remove();

            // Close associated sockets
            if (window.DecadeSocket) {
                window.DecadeSocket.closeSlotSockets(slotId);
            }

            const remainingIds = Object.keys(this.slots).map(Number);
            this.switchSlot(remainingIds[remainingIds.length - 1]);
        },

        loadJarForActive(file) {
            if (!file) return;
            const slot = this.getActiveSlot();
            slot.jarBlob = file;
            slot.running = true;

            const screen = document.getElementById('screen');
            screen.innerHTML = `
                <div style="color: #63b3ed; text-align: center; padding: 20px;">
                    <div style="font-size: 24px; margin-bottom: 8px;">&#9881;</div>
                    <div style="font-size: 14px; font-weight: bold;">Đang nạp file JAR...</div>
                    <div style="font-size: 11px; color: #a0aec0; margin-top: 4px;">${file.name}</div>
                </div>
            `;

            if (window.js2me && window.js2me.launchJAR) {
                try {
                    window.js2me.currentVM = slot.id;
                    window.js2me.launchJAR(file);
                } catch (e) {
                    console.error('Launch JAR Error:', e);
                    alert('Lỗi nạp JAR: ' + e.message);
                }
            }
        },

        showPlaceholder() {
            const screen = document.getElementById('screen');
            if (screen && !screen.hasChildNodes()) {
                screen.innerHTML = `
                    <div style="color: #94a3b8; text-align: center; padding: 20px; font-size: 13px;">
                        <div style="font-size: 32px; color: #ff2a5f; margin-bottom: 8px;">&#127918;</div>
                        <div style="font-weight: bold; color: #fff; margin-bottom: 4px;">DECADE J2ME ENGINE</div>
                        <div>Nhấn <b>&#9776; Menu</b> &rarr; <b>Nạp Game (.JAR)</b><br>để bắt đầu chơi.</div>
                    </div>
                `;
            }
        },

        updateHUD() {
            const slot = this.getActiveSlot();
            document.getElementById('slot-indicator').textContent = `SLOT ${slot.id}`;

            const netInd = document.getElementById('net-indicator');
            if (slot.proxy && slot.proxy.type !== 'DIRECT') {
                netInd.textContent = `PROXY: ${slot.proxy.type}`;
                netInd.style.color = '#f6ad55';
            } else if (slot.server && slot.server.override) {
                netInd.textContent = `IP: ${slot.server.host}`;
                netInd.style.color = '#63b3ed';
            } else {
                netInd.textContent = 'NET: DIRECT';
                netInd.style.color = '#68d391';
            }
        },

        bindEvents() {
            // Tab clicks
            document.getElementById('tabs-scroll').addEventListener('click', (e) => {
                const closeBtn = e.target.closest('.tab-close');
                if (closeBtn) {
                    e.stopPropagation();
                    this.closeSlot(parseInt(closeBtn.dataset.slot));
                    return;
                }
                const tabItem = e.target.closest('.tab-item');
                if (tabItem) {
                    this.switchSlot(parseInt(tabItem.dataset.slot));
                }
            });

            // Add Tab
            document.getElementById('btn-add-tab').addEventListener('click', () => {
                this.addSlot();
            });

            // Settings Modal
            const modal = document.getElementById('settings-modal');
            document.getElementById('btn-menu').addEventListener('click', () => {
                modal.classList.remove('hidden');
            });
            document.getElementById('modal-close').addEventListener('click', () => {
                modal.classList.add('hidden');
            });

            // File Picker
            const fileInput = document.getElementById('jar-file-input');
            fileInput.addEventListener('change', (e) => {
                if (e.target.files && e.target.files[0]) {
                    this.loadJarForActive(e.target.files[0]);
                    modal.classList.add('hidden');
                }
            });

            // Demo Mode (Interactive Canvas Test)
            document.getElementById('btn-load-demo').addEventListener('click', () => {
                this.runInteractiveDemo();
                modal.classList.add('hidden');
            });

            // Save IP
            document.getElementById('btn-save-ip').addEventListener('click', () => {
                const selectVal = document.getElementById('server-select').value;
                const slot = this.getActiveSlot();

                if (selectVal === 'custom') {
                    const ip = document.getElementById('custom-ip').value.trim();
                    const port = parseInt(document.getElementById('custom-port').value.trim()) || 14444;
                    if (ip) {
                        slot.server = { host: ip, port: port, override: true };
                    }
                } else {
                    const [ip, port] = selectVal.split(':');
                    slot.server = { host: ip, port: parseInt(port), override: true };
                }
                this.updateHUD();
                alert(`Đã gán Server [${slot.server.host}:${slot.server.port}] cho ${slot.name}!`);
                modal.classList.add('hidden');
            });

            // Save Proxy
            document.getElementById('btn-save-proxy').addEventListener('click', () => {
                const pType = document.getElementById('proxy-type').value;
                const pHost = document.getElementById('proxy-host').value.trim();
                const pPort = parseInt(document.getElementById('proxy-port').value.trim()) || 0;
                const slot = this.getActiveSlot();

                slot.proxy = { type: pType, host: pHost, port: pPort };
                this.updateHUD();
                alert(`Đã lưu cấu hình Proxy (${pType}) cho ${slot.name}!`);
                modal.classList.add('hidden');
            });

            // Keypad Event Handlers (Virtual Buttons)
            this.bindKeypad();
        },

        bindKeypad() {
            const keypad = document.getElementById('keypad');
            const handlePress = (e) => {
                const btn = e.target.closest('.key-btn');
                if (!btn) return;
                e.preventDefault();

                const keyName = btn.dataset.key;
                const keyCode = KEY_MAP[keyName];
                if (keyCode !== undefined && window.js2me) {
                    window.js2me.sendKeyPressEvent(keyCode);
                }
                if (navigator.vibrate) navigator.vibrate(12);
            };

            const handleRelease = (e) => {
                const btn = e.target.closest('.key-btn');
                if (!btn) return;
                e.preventDefault();

                const keyName = btn.dataset.key;
                const keyCode = KEY_MAP[keyName];
                if (keyCode !== undefined && window.js2me) {
                    window.js2me.sendKeyReleasedEvent(keyCode);
                }
            };

            keypad.addEventListener('touchstart', handlePress, { passive: false });
            keypad.addEventListener('touchend', handleRelease, { passive: false });
            keypad.addEventListener('mousedown', handlePress);
            keypad.addEventListener('mouseup', handleRelease);
        },

        runInteractiveDemo() {
            const screen = document.getElementById('screen');
            screen.innerHTML = '';
            const canvas = document.createElement('canvas');
            canvas.width = 240;
            canvas.height = 320;
            screen.appendChild(canvas);

            const ctx = canvas.getContext('2d');
            let frame = 0;
            let playerX = 110;
            let playerY = 150;

            const demoKeyHandler = (e) => {
                const code = e.detail;
                if (code === -1) playerY = Math.max(20, playerY - 10);
                if (code === -2) playerY = Math.min(280, playerY + 10);
                if (code === -3) playerX = Math.max(20, playerX - 10);
                if (code === -4) playerX = Math.min(210, playerX + 10);
            };
            window.addEventListener('decade-demo-key', demoKeyHandler);

            function render() {
                frame++;
                ctx.fillStyle = '#0f172a';
                ctx.fillRect(0, 0, 240, 320);

                // Grid background
                ctx.strokeStyle = '#1e293b';
                ctx.lineWidth = 1;
                for (let x = 0; x < 240; x += 20) {
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, 320); ctx.stroke();
                }
                for (let y = 0; y < 320; y += 20) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(240, y); ctx.stroke();
                }

                // Ninja Character Box
                ctx.fillStyle = '#ff2a5f';
                ctx.fillRect(playerX, playerY, 20, 20);
                ctx.strokeStyle = '#fff';
                ctx.strokeRect(playerX, playerY, 20, 20);

                // Text
                ctx.fillStyle = '#f8fafc';
                ctx.font = 'bold 12px monospace';
                ctx.fillText('DECADE ENGINE READY', 45, 40);
                ctx.fillStyle = '#38bdf8';
                ctx.font = '10px monospace';
                ctx.fillText('Am thanh: DA LOAI BO', 45, 60);
                ctx.fillText('Bam D-Pad de di chuyen', 45, 80);

                requestAnimationFrame(render);
            }
            render();
        }
    };

    // Native Socket Bridge Implementation
    window.DecadeSocket = {
        callbacks: {},
        socketSlotMap: {},

        open(socketId, host, port, onData) {
            this.callbacks[socketId] = onData;
            const currentSlot = SlotManager.getActiveSlot();
            this.socketSlotMap[socketId] = currentSlot.id;

            const serverConfig = currentSlot.server || { host: host, port: port, override: false };
            const proxyConfig = currentSlot.proxy || { type: 'DIRECT' };

            const targetHost = serverConfig.override ? serverConfig.host : host;
            const targetPort = serverConfig.override ? serverConfig.port : port;

            console.log(`[DecadeSocket] Connecting socket #${socketId} to ${targetHost}:${targetPort} via ${proxyConfig.type}`);

            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.decadeNative) {
                window.webkit.messageHandlers.decadeNative.postMessage({
                    action: 'socketConnect',
                    socketId: socketId,
                    host: targetHost,
                    port: targetPort,
                    proxyHost: proxyConfig.host || '',
                    proxyPort: proxyConfig.port || 0,
                    proxyType: proxyConfig.type || 'DIRECT'
                });
            } else {
                console.warn('[DecadeSocket] Native bridge not found (running in pure browser)');
            }
        },

        send(socketId, uint8Array) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.decadeNative) {
                let binary = '';
                for (let i = 0; i < uint8Array.length; i++) {
                    binary += String.fromCharCode(uint8Array[i]);
                }
                const base64 = btoa(binary);
                window.webkit.messageHandlers.decadeNative.postMessage({
                    action: 'socketSend',
                    socketId: socketId,
                    data: base64
                });
            }
        },

        close(socketId) {
            delete this.callbacks[socketId];
            delete this.socketSlotMap[socketId];
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.decadeNative) {
                window.webkit.messageHandlers.decadeNative.postMessage({
                    action: 'socketClose',
                    socketId: socketId
                });
            }
        },

        closeSlotSockets(slotId) {
            for (const [sId, slId] of Object.entries(this.socketSlotMap)) {
                if (slId === slotId) {
                    this.close(parseInt(sId));
                }
            }
        }
    };

    // Inbound callbacks from Swift Network.framework
    window.DecadeNative = {
        onSocketOpen(socketId) {
            console.log(`[DecadeNative] Socket #${socketId} open`);
        },

        onSocketData(socketId, base64Data) {
            if (window.DecadeSocket.callbacks[socketId]) {
                const binary = atob(base64Data);
                const bytes = new Uint8Array(binary.length);
                for (let i = 0; i < binary.length; i++) {
                    bytes[i] = binary.charCodeAt(i);
                }
                window.DecadeSocket.callbacks[socketId](bytes);
            }
        },

        onSocketClose(socketId) {
            console.log(`[DecadeNative] Socket #${socketId} closed`);
            delete window.DecadeSocket.callbacks[socketId];
        },

        onSocketError(socketId, errorMsg) {
            console.error(`[DecadeNative] Socket #${socketId} error: ${errorMsg}`);
        }
    };

    // Forward keypad to demo if demo is active
    const origSendKey = window.js2me ? window.js2me.sendKeyPressEvent : null;
    if (window.js2me) {
        window.js2me.sendKeyPressEvent = function (keyCode) {
            window.dispatchEvent(new CustomEvent('decade-demo-key', { detail: keyCode }));
            if (origSendKey) origSendKey.call(window.js2me, keyCode);
        };
    }

    // Initialize on DOM load
    document.addEventListener('DOMContentLoaded', () => {
        SlotManager.init();
    });

})();
