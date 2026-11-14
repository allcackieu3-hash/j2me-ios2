/**
 * KamenRider Decade iOS - 100% Authentic Android Experience Controller
 */

(function () {
    'use strict';

    // J2ME Canvas KeyCode Mappings
    const KEY_MAP = {
        'SOFT_LEFT': -6,
        'SOFT_RIGHT': -7,
        'UP': -1,
        'DOWN': -2,
        'LEFT': -3,
        'RIGHT': -4,
        'FIRE': -5,
        'UP_LEFT': 49,    // '1'
        'UP_RIGHT': 51,   // '3'
        'DOWN_LEFT': 55,  // '7'
        'DOWN_RIGHT': 57, // '9'
        '1': 49, '2': 50, '3': 51,
        '4': 52, '5': 53, '6': 54,
        '7': 55, '8': 56, '9': 57,
        'STAR': 42, '0': 48, 'HASH': 35
    };

    const App = {
        currentView: 'home', // 'home' | 'game'
        slots: {},
        activeSlotId: 1,
        nextSlotId: 2,
        embeddedJarBlob: null,

        init() {
            this.slots[1] = {
                id: 1,
                server: { host: '112.213.94.135', port: 14444, override: false },
                proxy: { type: 'DIRECT', host: '', port: 0 }
            };

            this.bindUI();
            this.preloadEmbeddedGame();
        },

        // Preload nic.jar bundled in app
        preloadEmbeddedGame() {
            try {
                const xhr = new XMLHttpRequest();
                xhr.open('GET', 'nic.jar', true);
                xhr.responseType = 'blob';
                xhr.onload = () => {
                    if (xhr.status === 200 || xhr.status === 0) {
                        this.embeddedJarBlob = xhr.response;
                        console.log('[Decade] Bundled nic.jar preloaded (' + xhr.response.size + ' bytes)');
                    }
                };
                xhr.onerror = (e) => {
                    console.warn('[Decade] Preload nic.jar XHR error:', e);
                };
                xhr.send();
            } catch (err) {
                console.warn('[Decade] Preload nic.jar exception:', err);
            }
        },

        // Navigation between Home and In-Game Screen
        showGameView() {
            document.getElementById('view-home').classList.add('hidden');
            document.getElementById('view-game').classList.remove('hidden');
            this.currentView = 'game';
        },

        showHomeView() {
            document.getElementById('view-game').classList.add('hidden');
            document.getElementById('view-home').classList.remove('hidden');
            this.currentView = 'home';
        },

        // Tab Management
        addSlot() {
            const id = this.nextSlotId++;
            this.slots[id] = {
                id: id,
                server: { host: '112.213.94.135', port: 14444, override: false },
                proxy: { type: 'DIRECT', host: '', port: 0 }
            };

            const tabEl = document.createElement('div');
            tabEl.className = 'decade-tab-box inactive';
            tabEl.dataset.slot = id;
            tabEl.textContent = id;
            document.getElementById('decade-tab-strip').appendChild(tabEl);

            this.switchSlot(id);
        },

        addManySlots(count) {
            for (let i = 0; i < count; i++) {
                this.addSlot();
            }
        },

        switchSlot(slotId) {
            if (!this.slots[slotId]) return;
            this.activeSlotId = slotId;

            document.querySelectorAll('.decade-tab-box').forEach(tab => {
                const isCurrent = parseInt(tab.dataset.slot) === slotId;
                tab.classList.toggle('inactive', !isCurrent);
            });

            if (window.js2me) {
                window.js2me.currentVM = slotId;
            }
        },

        launchGame(jarBlob, gameTitle) {
            if (!jarBlob) return;
            document.getElementById('active-game-title').textContent = gameTitle || 'a';
            this.showGameView();

            const screen = document.getElementById('screen');
            screen.innerHTML = `
                <div style="color: #63b3ed; text-align: center; padding: 20px;">
                    <div style="font-size: 26px; margin-bottom: 8px;">&#9881;</div>
                    <div style="font-size: 14px; font-weight: bold; color: #fff;">Đang nạp file JAR...</div>
                </div>
            `;

            if (window.js2me && window.js2me.launchJAR) {
                try {
                    window.js2me.currentVM = this.activeSlotId;
                    window.js2me.launchJAR(jarBlob);
                } catch (e) {
                    console.error('[Decade] Launch Error:', e);
                    alert('Lỗi nạp game: ' + e.message);
                }
            }
        },

        bindUI() {
            // Tap Game "a" on Home Screen
            const gameA = document.getElementById('item-game-a');
            const openGameA = () => {
                if (this.embeddedJarBlob) {
                    this.launchGame(this.embeddedJarBlob, 'a');
                } else {
                    const xhr = new XMLHttpRequest();
                    xhr.open('GET', 'nic.jar', true);
                    xhr.responseType = 'blob';
                    xhr.onload = () => {
                        if (xhr.status === 200 || xhr.status === 0) {
                            this.embeddedJarBlob = xhr.response;
                            this.launchGame(xhr.response, 'a');
                        } else {
                            alert('Chưa mở được nic.jar (Mã lỗi ' + xhr.status + ')');
                        }
                    };
                    xhr.onerror = (err) => {
                        alert('Lỗi nạp game a: ' + err);
                    };
                    xhr.send();
                }
            };
            gameA.addEventListener('click', openGameA);
            gameA.addEventListener('touchend', (e) => {
                e.preventDefault();
                openGameA();
            });

            // FAB "+" Button to pick other JARs
            const fabInput = document.getElementById('fab-file-input');
            document.getElementById('btn-fab-add').addEventListener('click', () => {
                fabInput.click();
            });
            fabInput.addEventListener('change', (e) => {
                if (e.target.files && e.target.files[0]) {
                    const file = e.target.files[0];
                    const name = file.name.replace(/\.jar$/i, '');
                    this.launchGame(file, name);
                }
            });

            // Home Menu "⋮" Popup
            const homeMenu = document.getElementById('home-menu-popup');
            document.getElementById('btn-home-menu').addEventListener('click', (e) => {
                e.stopPropagation();
                homeMenu.classList.toggle('hidden');
            });
            document.addEventListener('click', () => {
                homeMenu.classList.add('hidden');
                document.getElementById('in-game-menu-popup').classList.add('hidden');
            });

            // In-Game Menu "⋮" Popup
            const inGameMenu = document.getElementById('in-game-menu-popup');
            document.getElementById('btn-in-game-menu').addEventListener('click', (e) => {
                e.stopPropagation();
                inGameMenu.classList.toggle('hidden');
            });

            // In-Game Menu Actions
            document.getElementById('igm-exit').addEventListener('click', () => {
                this.showHomeView();
            });
            document.getElementById('menu-exit').addEventListener('click', () => {
                alert('Thoát KamenRider Decade');
            });

            // Add 1 Tab (+)
            document.getElementById('btn-add-one-tab').addEventListener('click', () => {
                this.addSlot();
            });

            // Add Many Tabs (++)
            const dialogMany = document.getElementById('dialog-many-tabs');
            document.getElementById('btn-add-many-tabs').addEventListener('click', () => {
                dialogMany.classList.remove('hidden');
            });
            document.getElementById('btn-cancel-many').addEventListener('click', () => {
                dialogMany.classList.add('hidden');
            });
            document.getElementById('btn-confirm-many').addEventListener('click', () => {
                const count = parseInt(document.getElementById('input-many-count').value) || 3;
                this.addManySlots(count);
                dialogMany.classList.add('hidden');
            });

            // Tab Click
            document.getElementById('decade-tab-strip').addEventListener('click', (e) => {
                const tab = e.target.closest('.decade-tab-box');
                if (tab) {
                    this.switchSlot(parseInt(tab.dataset.slot));
                }
            });

            // Keyboard View Toggle
            const dpadView = document.getElementById('dpad-view');
            const numpadView = document.getElementById('numpad-view');
            document.getElementById('btn-toggle-keypad').addEventListener('click', () => {
                if (dpadView.classList.contains('hidden')) {
                    dpadView.classList.remove('hidden');
                    numpadView.classList.add('hidden');
                } else {
                    dpadView.classList.add('hidden');
                    numpadView.classList.remove('hidden');
                }
            });

            // IP Dialog
            const dialogIp = document.getElementById('dialog-ip');
            const openIpDialog = () => dialogIp.classList.remove('hidden');
            document.getElementById('menu-change-ip').addEventListener('click', openIpDialog);
            document.getElementById('igm-change-ip').addEventListener('click', openIpDialog);
            document.getElementById('btn-cancel-ip').addEventListener('click', () => dialogIp.classList.add('hidden'));
            document.getElementById('btn-confirm-ip').addEventListener('click', () => {
                const val = document.getElementById('select-nso-server').value;
                const slot = this.slots[this.activeSlotId];
                if (val === 'custom') {
                    const ip = document.getElementById('input-ip-val').value.trim();
                    const port = parseInt(document.getElementById('input-port-val').value) || 14444;
                    if (ip) slot.server = { host: ip, port: port, override: true };
                } else {
                    const [ip, port] = val.split(':');
                    slot.server = { host: ip, port: parseInt(port), override: true };
                }
                alert(`Đã lưu Server [${slot.server.host}:${slot.server.port}] cho Tab ${slot.id}!`);
                dialogIp.classList.add('hidden');
            });

            // Proxy Dialog
            const dialogProxy = document.getElementById('dialog-proxy');
            const openProxyDialog = () => dialogProxy.classList.remove('hidden');
            document.getElementById('menu-proxy-manager').addEventListener('click', openProxyDialog);
            document.getElementById('igm-bind-proxy').addEventListener('click', openProxyDialog);
            document.getElementById('igm-add-proxy').addEventListener('click', openProxyDialog);
            document.getElementById('btn-cancel-proxy').addEventListener('click', () => dialogProxy.classList.add('hidden'));
            document.getElementById('btn-confirm-proxy').addEventListener('click', () => {
                const pType = document.getElementById('select-proxy-type').value;
                const pHost = document.getElementById('input-proxy-host').value.trim();
                const pPort = parseInt(document.getElementById('input-proxy-port').value) || 1080;
                const slot = this.slots[this.activeSlotId];
                slot.proxy = { type: pType, host: pHost, port: pPort };
                alert(`Đã gán Proxy [${pType}] cho Tab ${slot.id}!`);
                dialogProxy.classList.add('hidden');
            });

            this.bindKeypad();
            this.bindTouchScreen();
        },

        bindKeypad() {
            const keypad = document.getElementById('virtual-keypad-panel');
            const handlePress = (e) => {
                const btn = e.target.closest('button[data-key]');
                if (!btn) return;
                e.preventDefault();

                const keyName = btn.dataset.key;
                const keyCode = KEY_MAP[keyName];
                if (keyCode !== undefined && window.js2me) {
                    window.js2me.sendKeyPressEvent(keyCode);
                }
                if (navigator.vibrate) navigator.vibrate(10);
            };

            const handleRelease = (e) => {
                const btn = e.target.closest('button[data-key]');
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

        bindTouchScreen() {
            const screen = document.getElementById('screen');
            screen.addEventListener('touchstart', (e) => {
                const canvas = screen.querySelector('canvas');
                if (!canvas || !window.js2me) return;
                const rect = canvas.getBoundingClientRect();
                const touch = e.touches[0];
                const x = Math.floor((touch.clientX - rect.left) * (canvas.width / rect.width));
                const y = Math.floor((touch.clientY - rect.top) * (canvas.height / rect.height));

                if (window.js2me.currentCanvas && window.js2me.currentCanvas.$pointerPressed$II$V) {
                    window.js2me.currentCanvas.$pointerPressed$II$V(x, y);
                }
            }, { passive: true });
        }
    };

    // Native Socket Bridge
    window.DecadeSocket = {
        callbacks: {},
        open(socketId, host, port, onData) {
            this.callbacks[socketId] = onData;
            const slot = App.slots[App.activeSlotId] || { server: {}, proxy: {} };
            const targetHost = (slot.server && slot.server.override) ? slot.server.host : host;
            const targetPort = (slot.server && slot.server.override) ? slot.server.port : port;
            const pType = (slot.proxy && slot.proxy.type) || 'DIRECT';

            console.log(`[DecadeSocket] #${socketId} connecting ${targetHost}:${targetPort} via ${pType}`);

            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.decadeNative) {
                window.webkit.messageHandlers.decadeNative.postMessage({
                    action: 'socketConnect',
                    socketId: socketId,
                    host: targetHost,
                    port: targetPort,
                    proxyHost: slot.proxy.host || '',
                    proxyPort: slot.proxy.port || 0,
                    proxyType: pType
                });
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
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.decadeNative) {
                window.webkit.messageHandlers.decadeNative.postMessage({
                    action: 'socketClose',
                    socketId: socketId
                });
            }
        }
    };

    window.DecadeNative = {
        onSocketOpen(socketId) {
            console.log(`[DecadeNative] Socket #${socketId} opened`);
        },
        onSocketData(socketId, base64Data) {
            if (window.DecadeSocket.callbacks[socketId]) {
                const binary = atob(base64Data);
                const bytes = new Uint8Array(binary.length);
                for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
                window.DecadeSocket.callbacks[socketId](bytes);
            }
        },
        onSocketClose(socketId) {
            delete window.DecadeSocket.callbacks[socketId];
        },
        onSocketError(socketId, errorMsg) {
            console.error(`[DecadeNative] Socket #${socketId} error: ${errorMsg}`);
        }
    };

    document.addEventListener('DOMContentLoaded', () => {
        App.init();
    });

})();
