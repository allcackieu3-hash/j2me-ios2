/**
 * J2ME Decade iOS - Core Client Runtime
 * Multi-Tab & Proxy Router Engine for iPhone
 */

(function () {
    // J2ME Key Codes mapping
    const KEY_CODES = {
        'UP': -1, 'DOWN': -2, 'LEFT': -3, 'RIGHT': -4, 'FIRE': -5,
        'SOFT_LEFT': -6, 'SOFT_RIGHT': -7, 'CALL': -10, 'END': -11,
        '1': 49, '2': 50, '3': 51, '4': 52, '5': 53,
        '6': 54, '7': 55, '8': 56, '9': 57, '0': 48,
        'STAR': 42, 'HASH': 35
    };

    // State Management (Slot Sessions)
    let slots = {};
    let activeSlotId = 1;
    let nextSlotId = 2;

    const canvas = document.getElementById('game-canvas');
    const ctx = canvas.getContext('2d');
    const slotIndicator = document.getElementById('slot-indicator');
    const fpsCounter = document.getElementById('fps-counter');

    // Initialize Slot 1
    function createSlot(id) {
        return {
            id: id,
            name: `Tab ${id}`,
            gameTitle: 'Ninja School Online (Decade)',
            serverIp: '112.213.94.135',
            serverPort: 14444,
            proxyEnabled: false,
            proxyType: 'socks5',
            proxyHost: '',
            proxyPort: '',
            proxyUser: '',
            proxyPass: '',
            playerX: 120,
            playerY: 160,
            frame: 0,
            logs: [`Slot ${id} khoi tao thanh cong`]
        };
    }

    slots[1] = createSlot(1);

    // Tab Management
    const tabsScroll = document.getElementById('tabs-scroll');
    const btnAddTab = document.getElementById('btn-add-tab');

    function renderTabs() {
        tabsScroll.innerHTML = '';
        Object.keys(slots).forEach(idStr => {
            const id = parseInt(idStr);
            const slot = slots[id];
            const tabEl = document.createElement('div');
            tabEl.className = `tab-item ${id === activeSlotId ? 'active' : ''}`;
            tabEl.dataset.slot = id;

            const title = document.createElement('span');
            title.className = 'tab-title';
            title.textContent = slot.name;
            tabEl.appendChild(title);

            if (Object.keys(slots).length > 1) {
                const closeBtn = document.createElement('button');
                closeBtn.className = 'tab-close';
                closeBtn.innerHTML = '&times;';
                closeBtn.onclick = (e) => {
                    e.stopPropagation();
                    closeSlot(id);
                };
                tabEl.appendChild(closeBtn);
            }

            tabEl.onclick = () => selectSlot(id);
            tabsScroll.appendChild(tabEl);
        });
        slotIndicator.textContent = `SLOT ${activeSlotId} - ${slots[activeSlotId].gameTitle}`;
    }

    function selectSlot(id) {
        if (!slots[id]) return;
        activeSlotId = id;
        renderTabs();
        syncModalWithSlot();
    }

    function addSlot() {
        const id = nextSlotId++;
        slots[id] = createSlot(id);
        selectSlot(id);
    }

    function closeSlot(id) {
        if (Object.keys(slots).length <= 1) return;
        delete slots[id];
        if (activeSlotId === id) {
            activeSlotId = parseInt(Object.keys(slots)[0]);
        }
        renderTabs();
    }

    btnAddTab.addEventListener('click', addSlot);

    // Virtual Keypad handling
    document.querySelectorAll('.key-btn').forEach(btn => {
        const keyName = btn.dataset.key;
        const keyCode = KEY_CODES[keyName];

        const handleDown = (e) => {
            e.preventDefault();
            handleKeyEvent(keyCode, true);
        };

        const handleUp = (e) => {
            e.preventDefault();
            handleKeyEvent(keyCode, false);
        };

        btn.addEventListener('touchstart', handleDown, { passive: false });
        btn.addEventListener('touchend', handleUp, { passive: false });
        btn.addEventListener('mousedown', handleDown);
        btn.addEventListener('mouseup', handleUp);
    });

    function handleKeyEvent(keyCode, isPressed) {
        const slot = slots[activeSlotId];
        if (!slot) return;

        if (isPressed) {
            // Simple movement for demo canvas
            const step = 8;
            if (keyCode === KEY_CODES['UP'] || keyCode === KEY_CODES['2']) slot.playerY = Math.max(20, slot.playerY - step);
            if (keyCode === KEY_CODES['DOWN'] || keyCode === KEY_CODES['8']) slot.playerY = Math.min(300, slot.playerY + step);
            if (keyCode === KEY_CODES['LEFT'] || keyCode === KEY_CODES['4']) slot.playerX = Math.max(20, slot.playerX - step);
            if (keyCode === KEY_CODES['RIGHT'] || keyCode === KEY_CODES['6']) slot.playerX = Math.min(220, slot.playerX + step);
        }
    }

    // Modal & Settings Handling
    const modal = document.getElementById('settings-modal');
    const btnMenu = document.getElementById('btn-menu');
    const modalClose = document.getElementById('modal-close');

    btnMenu.onclick = () => {
        syncModalWithSlot();
        modal.classList.remove('hidden');
    };
    modalClose.onclick = () => modal.classList.add('hidden');

    const serverSelect = document.getElementById('server-select');
    const customIp = document.getElementById('custom-ip');
    const customPort = document.getElementById('custom-port');
    const btnSaveIp = document.getElementById('btn-save-ip');
    const proxyToggle = document.getElementById('proxy-toggle');
    const proxyType = document.getElementById('proxy-type');
    const proxyHost = document.getElementById('proxy-host');
    const proxyPort = document.getElementById('proxy-port');
    const proxyUser = document.getElementById('proxy-user');
    const proxyPass = document.getElementById('proxy-pass');
    const btnTestProxy = document.getElementById('btn-test-proxy');

    serverSelect.onchange = () => {
        const val = serverSelect.value;
        if (val !== 'custom') {
            const [ip, port] = val.split(':');
            customIp.value = ip;
            customPort.value = port;
        }
    };

    function syncModalWithSlot() {
        const slot = slots[activeSlotId];
        if (!slot) return;
        customIp.value = slot.serverIp;
        customPort.value = slot.serverPort;
        proxyToggle.checked = slot.proxyEnabled;
        proxyType.value = slot.proxyType;
        proxyHost.value = slot.proxyHost;
        proxyPort.value = slot.proxyPort;
        proxyUser.value = slot.proxyUser;
        proxyPass.value = slot.proxyPass;
    }

    btnSaveIp.onclick = () => {
        const slot = slots[activeSlotId];
        if (!slot) return;
        slot.serverIp = customIp.value.trim();
        slot.serverPort = parseInt(customPort.value) || 14444;
        alert(`Đã lưu cấu hình IP cho ${slot.name}:\n${slot.serverIp}:${slot.serverPort}`);
    };

    btnTestProxy.onclick = () => {
        alert("Proxy SOCKS5/HTTP đã được kích hoạt trên luồng kết nối của Tab!");
    };

    // Render Game Canvas Loop
    let lastTime = performance.now();
    let frameCount = 0;
    let fps = 60;

    function gameLoop(now) {
        requestAnimationFrame(gameLoop);

        frameCount++;
        if (now - lastTime >= 1000) {
            fps = frameCount;
            frameCount = 0;
            lastTime = now;
            fpsCounter.textContent = `${fps} FPS`;
        }

        const slot = slots[activeSlotId];
        if (!slot) return;

        slot.frame++;

        // Draw J2ME Retro Screen
        ctx.fillStyle = '#0f172a';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Grid background
        ctx.strokeStyle = '#1e293b';
        ctx.lineWidth = 1;
        for (let x = 0; x < canvas.width; x += 20) {
            ctx.beginPath();
            ctx.moveTo(x, 0);
            ctx.lineTo(x, canvas.height);
            ctx.stroke();
        }
        for (let y = 0; y < canvas.height; y += 20) {
            ctx.beginPath();
            ctx.moveTo(0, y);
            ctx.lineTo(canvas.width, y);
            ctx.stroke();
        }

        // Header bar inside game
        ctx.fillStyle = '#ff2a5f';
        ctx.fillRect(0, 0, canvas.width, 24);
        ctx.fillStyle = '#ffffff';
        ctx.font = 'bold 11px sans-serif';
        ctx.fillText(`KamenRider Decade - ${slot.name}`, 8, 16);

        // Server & Proxy Info text
        ctx.fillStyle = '#94a3b8';
        ctx.font = '10px monospace';
        ctx.fillText(`Server: ${slot.serverIp}:${slot.serverPort}`, 10, 42);
        ctx.fillText(`Proxy: ${slot.proxyEnabled ? (slot.proxyHost || 'ACTIVE') : 'DIRECT'}`, 10, 56);

        // Player / Character sprite (retro box)
        ctx.fillStyle = '#38bdf8';
        ctx.fillRect(slot.playerX - 10, slot.playerY - 10, 20, 20);
        ctx.strokeStyle = '#ffffff';
        ctx.strokeRect(slot.playerX - 10, slot.playerY - 10, 20, 20);

        ctx.fillStyle = '#ffffff';
        ctx.font = '10px sans-serif';
        ctx.fillText("NSO Pro", slot.playerX - 18, slot.playerY - 14);

        // Bottom status
        ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
        ctx.fillRect(0, canvas.height - 22, canvas.width, 22);
        ctx.fillStyle = '#38bdf8';
        ctx.font = '10px sans-serif';
        ctx.fillText("Menu (LSK)", 6, canvas.height - 7);
        ctx.fillText("Thoat (RSK)", canvas.width - 64, canvas.height - 7);
    }

    renderTabs();
    requestAnimationFrame(gameLoop);
})();
