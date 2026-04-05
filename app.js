function generateUUID() {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

class PlannerTask {
    constructor(title, note, date, isCompleted, priority, category, notificationTime, id) {
        this.id = id || generateUUID();
        this.title = title;
        this.note = note || null;
        this.date = new Date(date).toISOString();
        this.isCompleted = isCompleted || false;
        this.priority = priority || 'medium';
        this.category = category || 'personal';
        this.notificationTime = notificationTime ? new Date(notificationTime).toISOString() : null;
    }
}

class Note {
    constructor(title, content, date, imagePath, audioPath, isPinned, noteColor, id) {
        this.id = id || generateUUID();
        this.title = title;
        this.content = content;
        this.date = new Date(date || Date.now()).toISOString();
        this.imagePath = imagePath || null;
        this.audioPath = audioPath || null;
        this.isPinned = isPinned || false;
        this.noteColor = noteColor || 'blue';
    }
}

// --- DATABASE WRAPPER (IndexedDB) ---
const LocalDB = {
    dbName: 'PlanlayiciDB',
    version: 1,
    db: null,

    init() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(this.dbName, this.version);
            request.onupgradeneeded = (e) => {
                const db = e.target.result;
                if (!db.objectStoreNames.contains('app_data')) {
                    db.createObjectStore('app_data');
                }
            };
            request.onsuccess = (e) => {
                this.db = e.target.result;
                resolve();
            };
            request.onerror = (e) => reject(e.target.error);
        });
    },

    get(key) {
        return new Promise((resolve) => {
            const transaction = this.db.transaction(['app_data'], 'readonly');
            const store = transaction.objectStore('app_data');
            const request = store.get(key);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => resolve(null);
        });
    },

    set(key, value) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['app_data'], 'readwrite');
            const store = transaction.objectStore('app_data');
            const request = store.put(value, key);
            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }
};

// --- STATE MANAGEMENT ---
const AppState = {
    tasks: [], notes: [],
    settings: { isDarkMode: false, appThemeColor: 'blue', morningNotification: false, eveningNotification: false },
    
    async load() {
        await LocalDB.init();
        const storedTasks = await LocalDB.get('tasks');
        if (storedTasks) this.tasks = storedTasks;
        const storedNotes = await LocalDB.get('notes');
        if (storedNotes) this.notes = storedNotes;
        const storedSettings = await LocalDB.get('settings');
        if (storedSettings) this.settings = { ...this.settings, ...storedSettings };
    },
    async saveTasks() { 
        await LocalDB.set('tasks', this.tasks);
        renderDaily(); renderCalendar(); renderStats();
    },
    async saveNotes() { 
        await LocalDB.set('notes', this.notes);
        renderNotes();
    },
    async saveSettings() { 
        await LocalDB.set('settings', this.settings);
        applyTheme();
    },
    
    async addTask(title, note, date, priority, category, notificationTime) {
        this.tasks.push(new PlannerTask(title, note, date, false, priority, category, notificationTime));
        await this.saveTasks();
    },
    async deleteTask(id) { 
        this.tasks = this.tasks.filter(t => t.id !== id); 
        await this.saveTasks(); 
    },
    async toggleCompletion(id) {
        const task = this.tasks.find(t => t.id === id);
        if (task) { task.isCompleted = !task.isCompleted; await this.saveTasks(); }
    },
    async saveOrUpdateNote(id, title, content, imagePath, audioPath, isPinned, noteColor) {
        if(id) {
            const existing = this.notes.find(n => n.id === id);
            if(existing) {
                existing.title = title; existing.content = content;
                if (imagePath !== undefined) existing.imagePath = imagePath;
                if (audioPath !== undefined) existing.audioPath = audioPath;
                existing.isPinned = isPinned; existing.noteColor = noteColor;
            }
        } else {
            this.notes.push(new Note(title || "Adsız Not", content, null, imagePath, audioPath, isPinned, noteColor));
        }
        await this.saveNotes();
    },
    async deleteNote(id) { 
        this.notes = this.notes.filter(n => n.id !== id); 
        await this.saveNotes(); 
    }
};

// --- CONSTANTS ---
const ThemeHex = {
    blue: "#007AFF",
    purple: "#AF52DE",
    green: "#34C759",
    orange: "#FF9500",
    red: "#FF3B30",
    pink: "#FF2D55",
    yellow: "#FFCC00",
    gray: "#8E8E93"
};
const Categories = {
    personal: { name: "Kişisel", icon: "ph-user", color: "var(--ios-blue)" },
    work: { name: "İş", icon: "ph-briefcase", color: "var(--ios-purple)" },
    home: { name: "Ev", icon: "ph-house", color: "var(--ios-orange)" },
    health: { name: "Sağlık", icon: "ph-heart", color: "var(--ios-red)" },
    other: { name: "Diğer", icon: "ph-tag", color: "var(--ios-gray)" }
};
const Priorities = {
    low: { name: "Düşük", icon: "ph-arrow-down", color: "var(--ios-green)" },
    medium: { name: "Orta", icon: "ph-minus", color: "var(--ios-orange)" },
    high: { name: "Yüksek", icon: "ph-warning-circle", color: "var(--ios-red)" }
};

function formatShortTime(isoStr) { if(!isoStr) return ""; const d = new Date(isoStr); return d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' }); }
function isSameDay(d1, d2) { return d1.getFullYear() === d2.getFullYear() && d1.getMonth() === d2.getMonth() && d1.getDate() === d2.getDate(); }

// --- UI LOGIC ---
let activeTab = 'view-daily';
let dailySelectedDate = new Date();
let dailyVisibleWeekStart = getStartOfWeek(new Date());
let calendarMonth = new Date();
calendarMonth.setDate(1);

document.addEventListener('DOMContentLoaded', async () => {
    await AppState.load();
    applyTheme();
    setupTabNavigation();
    setupModals();
    setupSettings();
    renderAll();
    
    // Request notification perms
    if (Notification.permission !== "granted" && Notification.permission !== "denied") {
        Notification.requestPermission();
    }
});

function applyTheme() {
    document.body.setAttribute('data-theme', AppState.settings.isDarkMode ? 'dark' : 'light');
    document.documentElement.style.setProperty('--theme-color', `var(--ios-${AppState.settings.appThemeColor})`);
    
    document.getElementById('setting-dark-mode').checked = AppState.settings.isDarkMode;
    document.getElementById('setting-morning-notif').checked = AppState.settings.morningNotification;
    document.getElementById('setting-evening-notif').checked = AppState.settings.eveningNotification;
    
    document.querySelectorAll('.theme-color-btn').forEach(btn => {
        btn.classList.toggle('selected', btn.dataset.theme === AppState.settings.appThemeColor);
    });
}

function setupSettings() {
    document.getElementById('setting-dark-mode').addEventListener('change', e => { AppState.settings.isDarkMode = e.target.checked; AppState.saveSettings(); });
    document.getElementById('setting-morning-notif').addEventListener('change', e => { AppState.settings.morningNotification = e.target.checked; AppState.saveSettings(); });
    document.getElementById('setting-evening-notif').addEventListener('change', e => { AppState.settings.eveningNotification = e.target.checked; AppState.saveSettings(); });
    document.querySelectorAll('.theme-color-btn').forEach(btn => {
        btn.addEventListener('click', () => { AppState.settings.appThemeColor = btn.dataset.theme; AppState.saveSettings(); });
    });
}

function setupTabNavigation() {
    document.querySelectorAll('.tab-item').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.tab-item').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
            btn.classList.add('active');
            activeTab = btn.dataset.tab;
            document.getElementById(activeTab).classList.add('active');
            if(activeTab==='view-statistics') renderStats();
        });
    });
}

function renderAll() {
    renderDaily();
    renderCalendar();
    renderNotes();
}

function getStartOfWeek(date) {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    return new Date(d.setDate(diff));
}

// --- DAILY PLANNER VIEW ---
function renderDaily() {
    // 1. Render Week Header
    const weekContainer = document.getElementById('weekly-swipe-container');
    weekContainer.innerHTML = '';
    const start = new Date(dailyVisibleWeekStart);
    document.getElementById('daily-nav-title').textContent = start.toLocaleDateString('tr-TR', {month:'long', year:'numeric'});
    
    for(let i=0; i<7; i++) {
        const d = new Date(start); d.setDate(start.getDate() + i);
        const dayEl = document.createElement('div');
        dayEl.className = 'day-item';
        const isSelected = isSameDay(d, dailySelectedDate);
        dayEl.innerHTML = `
            <span class="day-name">${d.toLocaleDateString('tr-TR',{weekday:'short'})}</span>
            <span class="day-number ${isSelected?'selected':''}">${d.getDate()}</span>
        `;
        dayEl.onclick = () => { dailySelectedDate = d; renderDaily(); };
        weekContainer.appendChild(dayEl);
    }
    
    // 2. Render Tasks
    const dayTasks = AppState.tasks.filter(t => isSameDay(new Date(t.date), dailySelectedDate))
        .sort((a,b) => {
            if(a.isCompleted === b.isCompleted) return new Date(a.date) - new Date(b.date);
            return a.isCompleted ? 1 : -1;
        });
    
    const emptyState = document.getElementById('daily-empty-state');
    const contentArea = document.getElementById('daily-content-area');
    
    if(dayTasks.length === 0) {
        emptyState.classList.remove('hidden');
        contentArea.classList.add('hidden');
    } else {
        emptyState.classList.add('hidden');
        contentArea.classList.remove('hidden');
        
        let completed = dayTasks.filter(t=>t.isCompleted).length;
        let prog = Math.round((completed / dayTasks.length) * 100);
        document.getElementById('daily-progress-text').textContent = `${prog}%`;
        document.getElementById('daily-progress-fill').style.width = `${prog}%`;
        
        const list = document.getElementById('task-list');
        list.innerHTML = '';
        dayTasks.forEach(task => {
            const cat = Categories[task.category];
            const prio = Priorities[task.priority];
            const div = document.createElement('div');
            div.className = `task-card ${task.isCompleted ? 'completed' : ''}`;
            
            div.innerHTML = `
                <button class="task-check-btn" onclick="AppState.toggleCompletion('${task.id}')">
                    <i class="${task.isCompleted ? 'ph-fill ph-check-circle' : 'ph ph-circle'}"></i>
                </button>
                <div class="task-content">
                    <span class="task-title">${task.title}</span>
                    <div class="task-badges">
                        <span class="badge" style="background:${cat.color}33; color:${cat.color}">
                            <i class="${cat.icon}"></i> ${cat.name}
                        </span>
                        ${task.notificationTime ? `<span class="badge badge-time"><i class="ph ph-clock"></i> ${formatShortTime(task.notificationTime)}</span>` : ''}
                        ${task.priority === 'high' && !task.isCompleted ? `<i class="ph-fill ph-warning-circle" style="color:var(--ios-red)"></i>` : ''}
                    </div>
                </div>
                <button class="task-menu-btn" onclick="toggleTaskDelete(this)"><i class="ph-bold ph-dots-three"></i></button>
                <div class="delete-overlay" onclick="AppState.deleteTask('${task.id}')"><i class="ph-fill ph-trash"></i></div>
            `;
            list.appendChild(div);
        });
    }
}
window.toggleTaskDelete = (btn) => {
    btn.parentElement.classList.toggle('show-delete');
};

document.getElementById('btn-today').onclick = () => {
    dailySelectedDate = new Date();
    dailyVisibleWeekStart = getStartOfWeek(new Date());
    renderDaily();
};
// basic swipe simulation for week header
let touchStartX = 0;
document.getElementById('weekly-swipe-container').addEventListener('touchstart', e => touchStartX = e.changedTouches[0].screenX);
document.getElementById('weekly-swipe-container').addEventListener('touchend', e => {
    let touchEndX = e.changedTouches[0].screenX;
    if(touchEndX < touchStartX - 50) { dailyVisibleWeekStart.setDate(dailyVisibleWeekStart.getDate() + 7); renderDaily(); } // Left
    if(touchEndX > touchStartX + 50) { dailyVisibleWeekStart.setDate(dailyVisibleWeekStart.getDate() - 7); renderDaily(); } // Right
});


// --- CALENDAR VIEW ---
function renderCalendar() {
    document.getElementById('calendar-month-year').textContent = calendarMonth.toLocaleDateString('tr-TR', {month:'long', year:'numeric'});
    const grid = document.getElementById('calendar-grid');
    grid.innerHTML = '';
    
    let firstDayInMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1);
    let daysInMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 0).getDate();
    
    let dayOfWeek = firstDayInMonth.getDay();
    let startingSpaces = (dayOfWeek + 6) % 7; // Monday start
    
    for(let i=0; i<startingSpaces; i++) {
        const d = document.createElement('div');
        grid.appendChild(d);
    }
    
    for(let i=1; i<=daysInMonth; i++) {
        const cellDate = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), i);
        const cell = document.createElement('div');
        cell.className = 'calendar-cell';
        if(isSameDay(cellDate, dailySelectedDate)) cell.classList.add('selected');
        
        let indicatorColor = null;
        let cellTasks = AppState.tasks.filter(t => isSameDay(new Date(t.date), cellDate));
        if(cellTasks.length > 0) {
            if(cellTasks.some(t => t.priority === 'high')) indicatorColor = 'var(--ios-red)';
            else if(cellTasks.some(t => t.priority === 'medium')) indicatorColor = 'var(--ios-orange)';
            else indicatorColor = 'var(--ios-green)';
        }
        
        cell.innerHTML = `
            <span>${i}</span>
            <div class="task-dot" style="background-color: ${indicatorColor || 'transparent'}"></div>
        `;
        cell.onclick = () => { dailySelectedDate = cellDate; renderCalendar(); renderDaily(); activeTab='view-daily'; document.querySelector('.tab-item[data-tab="view-daily"]').click(); };
        grid.appendChild(cell);
    }
    
    // Selected Date Tasks List below calendar
    document.getElementById('calendar-selected-date-title').textContent = `${dailySelectedDate.getDate()} ${dailySelectedDate.toLocaleDateString('tr-TR',{month:'long'})} Planları`;
    const calList = document.getElementById('calendar-task-list');
    calList.innerHTML = '';
    const dTasks = AppState.tasks.filter(t => isSameDay(new Date(t.date), dailySelectedDate));
    if(dTasks.length === 0) {
        calList.innerHTML = `<div style="padding:40px; text-align:center; color:var(--text-secondary)"><i class="ph ph-calendar-blank" style="font-size:40px;opacity:0.3"></i><br>Etkinlik Yok</div>`;
    } else {
        dTasks.forEach(task => {
            const cat = Categories[task.category];
            const div = document.createElement('div');
            div.className = `cal-task-item`;
            div.innerHTML = `
                <div class="cal-task-dot" style="background:${cat.color}"></div>
                <div style="flex:1">
                    <div style="${task.isCompleted ? 'text-decoration:line-through;color:var(--text-secondary)' : ''}">${task.title}</div>
                    ${task.notificationTime ? `<div style="font-size:12px;color:var(--text-secondary)">${formatShortTime(task.notificationTime)}</div>` : ''}
                </div>
                ${task.isCompleted ? `<i class="ph-bold ph-check" style="color:var(--ios-green)"></i>` : ''}
            `;
            calList.appendChild(div);
        });
    }
}
document.getElementById('btn-prev-month').onclick = () => { calendarMonth.setMonth(calendarMonth.getMonth() - 1); renderCalendar(); };
document.getElementById('btn-next-month').onclick = () => { calendarMonth.setMonth(calendarMonth.getMonth() + 1); renderCalendar(); };


// --- NOTES VIEW ---
document.getElementById('note-search-input').addEventListener('input', renderNotes);
function renderNotes() {
    const term = document.getElementById('note-search-input').value.toLowerCase();
    const list = document.getElementById('notes-list');
    list.innerHTML = '';
    
    let filtered = AppState.notes.filter(n => n.title.toLowerCase().includes(term) || n.content.toLowerCase().includes(term));
    filtered.sort((a,b) => (b.isPinned ? 1 : 0) - (a.isPinned ? 1 : 0)); // pinned first
    
    filtered.forEach(note => {
        const div = document.createElement('div');
        div.className = 'note-card';
        div.style.backgroundColor = `var(--ios-${note.noteColor})`;
        div.style.opacity = '0.15'; 
        // Need wrapper to fix opacity affecting text... wait, simpler: background rgba
        
        let colorObj = ThemeHex[note.noteColor] || ThemeHex.blue;
        // manually apply hex with transparency
        div.style.backgroundColor = colorObj + '26'; // 15% opacity hex roughly
        div.style.opacity = '1';

        div.innerHTML = `
            ${note.isPinned ? `<i class="ph-fill ph-push-pin pin-icon"></i>` : ''}
            <div class="note-title">${note.title}</div>
            <div class="note-meta" style="margin-bottom:8px">
                <span>${new Date(note.date).toLocaleDateString('tr-TR', {day:'numeric', month:'short'})}</span>
            </div>
            <div class="note-content">${note.content}</div>
            <div class="note-meta">
                ${note.imagePath ? `<span><i class="ph ph-paperclip"></i> Belge/Görsel</span>` : ''}
                ${note.audioPath ? `<span><i class="ph ph-microphone"></i> Ses Kaydı</span>` : ''}
            </div>
            <div class="delete-overlay" onclick="event.stopPropagation(); AppState.deleteNote('${note.id}')"><i class="ph-fill ph-trash"></i></div>
            <button class="task-menu-btn" onclick="event.stopPropagation(); window.toggleTaskDelete(this)" style="position:absolute; bottom:10px; right:10px"><i class="ph-bold ph-dots-three"></i></button>
        `;
        div.onclick = () => openNoteSheet(note);
        list.appendChild(div);
    });
}


// --- STATISTICS VIEW ---
let statType = 'weekly';
document.getElementById('picker-weekly').onclick = (e) => { statType='weekly'; updateStatPickers(e.target); renderStats(); };
document.getElementById('picker-category').onclick = (e) => { statType='category'; updateStatPickers(e.target); renderStats(); };
function updateStatPickers(activeBtn) {
    document.querySelectorAll('.picker-btn').forEach(b => b.classList.remove('active'));
    activeBtn.classList.add('active');
}

function renderStats() {
    document.getElementById('stat-total-tasks').textContent = AppState.tasks.length;
    document.getElementById('stat-completed-tasks').textContent = AppState.tasks.filter(t=>t.isCompleted).length;
    
    const chartContent = document.getElementById('chart-content');
    chartContent.innerHTML = '';
    
    if(AppState.tasks.length === 0) {
        chartContent.innerHTML = `<p style="padding:20px;color:var(--text-secondary)">Henüz yeterli veri yok.</p>`;
        return;
    }

    if(statType === 'weekly') {
        document.getElementById('chart-title').textContent = "Son 7 Günlük Tamamlanma Oranı";
        // Calculate last 7 days
        for(let i=6; i>=0; i--) {
            const d = new Date(); d.setDate(d.getDate() - i);
            const dTasks = AppState.tasks.filter(t => isSameDay(new Date(t.date), d));
            let rate = 0;
            if(dTasks.length > 0) rate = dTasks.filter(t=>t.isCompleted).length / dTasks.length;
            
            let label = d.toLocaleDateString('tr-TR', {weekday:'short'});
            
            const group = document.createElement('div');
            group.className = 'chart-bar-group';
            group.innerHTML = `
                <div class="chart-bar" style="height:${rate * 100}%;"></div>
                <div class="chart-label">${label}</div>
            `;
            chartContent.appendChild(group);
        }
    } else {
        document.getElementById('chart-title').textContent = "Görevlerin Kategorilere Göre Dağılımı";
        // Calculate category distribution
        let catCounts = {};
        AppState.tasks.forEach(t => { catCounts[t.category] = (catCounts[t.category] || 0) + 1; });
        
        let conicStops = [];
        let curPerc = 0;
        let legendHTML = '';
        const total = AppState.tasks.length;
        
        Object.keys(catCounts).forEach(cat => {
            const perc = (catCounts[cat] / total) * 100;
            const cObj = Categories[cat];
            conicStops.push(`var(--ios-${cObj.color.replace('var(--ios-','').replace(')','')}) ${curPerc}% ${curPerc + perc}%`);
            curPerc += perc;
            legendHTML += `<div class="pie-legend-item"><div class="pie-legend-color" style="background:${cObj.color}"></div>${cObj.name} (${catCounts[cat]})</div>`;
        });
        
        chartContent.innerHTML = `
            <div style="width:100%; display:flex; flex-direction:column; align-items:center;">
                <div class="pie-chart" style="background: conic-gradient(${conicStops.join(', ')})"></div>
                <div class="pie-legend">${legendHTML}</div>
            </div>
        `;
    }
}


// --- MODALS / SHEETS (ADD TASK, ADD NOTE) ---
function setupModals() {
    const cancelBtns = document.querySelectorAll('.cancel-btn');
    cancelBtns.forEach(b => b.onclick = closeModals);
    document.querySelector('.modal-backdrop').onclick = closeModals;
    
    // Add Task
    document.getElementById('btn-add-task').onclick = () => {
        document.getElementById('task-title-input').value = '';
        document.getElementById('task-note-input').value = '';
        document.getElementById('task-date-input').value = new Date().toISOString().split('T')[0];
        document.getElementById('task-alarm-toggle').checked = false;
        document.getElementById('task-time-row').classList.add('hidden');
        openModal('sheet-add-task');
    };
    
    document.getElementById('task-alarm-toggle').onchange = (e) => {
        if(e.target.checked) document.getElementById('task-time-row').classList.remove('hidden');
        else document.getElementById('task-time-row').classList.add('hidden');
    };
    
    document.getElementById('btn-save-task').onclick = async () => {
        const title = document.getElementById('task-title-input').value.trim();
        if(!title) return;
        const note = document.getElementById('task-note-input').value;
        const dateRaw = document.getElementById('task-date-input').value;
        const cat = document.getElementById('task-category-select').value;
        const prio = document.getElementById('task-priority-select').value;
        const alarmOn = document.getElementById('task-alarm-toggle').checked;
        const timeVal = document.getElementById('task-time-input').value; // HH:mm
        
        let d = new Date(dateRaw);
        let notifTime = null;
        if(alarmOn && timeVal) {
            notifTime = new Date(dateRaw);
            const [h, m] = timeVal.split(':');
            notifTime.setHours(parseInt(h), parseInt(m));
        }
        
        await AppState.addTask(title, note, d, prio, cat, notifTime);
        closeModals();
    };
    
    // Add Note
    document.getElementById('btn-add-note').onclick = () => openNoteSheet(null);
    document.getElementById('note-image-input').onchange = (e) => {
        const file = e.target.files[0];
        if(!file) return;
        
        let maxSize = file.type.includes('pdf') ? 5000000 : 10000000;
        if(file.size > maxSize) { alert('Hata: Dosya çok büyük. Lütfen daha düşük boyutlu bir dosya seçin.'); return; }
        
        const reader = new FileReader();
        reader.onload = (event) => {
            const result = event.target.result;
            
            if (file.type.includes('pdf')) {
                document.getElementById('note-image-preview').style.display = 'none';
                const nameEl = document.getElementById('note-file-name');
                nameEl.textContent = '📄 ' + file.name;
                nameEl.style.display = 'block';
                document.getElementById('note-image-preview').dataset.basedata = result;
                document.getElementById('note-image-preview-container').classList.remove('hidden');
            } else if (file.type.startsWith('image/')) {
                // Compress Image using Canvas before storing
                const img = new Image();
                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    const MAX_WIDTH = 800; // max width for notes
                    let width = img.width; let height = img.height;
                    if (width > MAX_WIDTH) { height = Math.round(height * (MAX_WIDTH / width)); width = MAX_WIDTH; }
                    canvas.width = width; canvas.height = height;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, width, height);
                    
                    const compressedData = canvas.toDataURL('image/jpeg', 0.6); // 60% quality saves huge space
                    document.getElementById('note-image-preview').src = compressedData;
                    document.getElementById('note-image-preview').dataset.basedata = compressedData;
                    document.getElementById('note-image-preview').style.display = 'block';
                    document.getElementById('note-file-name').style.display = 'none';
                    document.getElementById('note-image-preview-container').classList.remove('hidden');
                };
                img.src = result;
            }
        };
        reader.readAsDataURL(file);
    };
    
    document.getElementById('note-image-remove').onclick = () => {
        document.getElementById('note-image-preview').src = '';
        delete document.getElementById('note-image-preview').dataset.basedata;
        document.getElementById('note-image-preview-container').classList.add('hidden');
        document.getElementById('note-image-input').value = '';
    };
    
    // Audio Recording
    let mediaRecorder = null;
    let audioChunks = [];
    let audioRecordTimer = null;
    let audioSeconds = 0;
    
    document.getElementById('btn-start-record').onclick = async () => {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            
            // Try to lower bitrate for extreme storage savings (approx 2KB per second)
            let options = { audioBitsPerSecond: 16000 }; 
            if(MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) options.mimeType = 'audio/webm;codecs=opus';
            
            mediaRecorder = new MediaRecorder(stream, options);
            audioChunks = [];
            mediaRecorder.ondataavailable = e => { if (e.data.size > 0) audioChunks.push(e.data); };
            mediaRecorder.onstop = () => {
                const blob = new Blob(audioChunks, { type: 'audio/webm' });
                const reader = new FileReader();
                reader.onload = (event) => {
                    document.getElementById('note-audio-preview').src = event.target.result;
                    document.getElementById('audio-preview-container').classList.remove('hidden');
                };
                reader.readAsDataURL(blob);
                stream.getTracks().forEach(track => track.stop());
            };
            
            mediaRecorder.start();
            document.getElementById('btn-start-record').classList.add('hidden');
            document.getElementById('audio-record-ui').classList.remove('hidden');
            
            audioSeconds = 0;
            document.getElementById('audio-time').textContent = '0:00';
            audioRecordTimer = setInterval(() => {
                audioSeconds++;
                const mins = Math.floor(audioSeconds / 60);
                const secs = (audioSeconds % 60).toString().padStart(2, '0');
                document.getElementById('audio-time').textContent = `${mins}:${secs}`;
            }, 1000);
            
        } catch (err) {
            alert("Mikrofon izni alınamadı: " + err.message);
        }
    };
    
    document.getElementById('btn-stop-record').onclick = () => {
        if(mediaRecorder && mediaRecorder.state === 'recording') {
            mediaRecorder.stop();
        }
        clearInterval(audioRecordTimer);
        document.getElementById('audio-record-ui').classList.add('hidden');
        document.getElementById('btn-start-record').classList.remove('hidden');
    };
    
    document.getElementById('note-audio-remove').onclick = () => {
         document.getElementById('note-audio-preview').removeAttribute('src');
         document.getElementById('audio-preview-container').classList.add('hidden');
    };
    
    document.querySelectorAll('.note-color-btn').forEach(btn => {
        btn.onclick = () => {
            document.querySelectorAll('.note-color-btn').forEach(b => b.classList.remove('selected'));
            btn.classList.add('selected');
        };
    });
    
    document.getElementById('btn-save-note').onclick = async () => {
        try {
            const id = document.getElementById('note-id-hidden').value;
            const title = document.getElementById('note-title-input').value.trim();
            const content = document.getElementById('note-content-input').value;
            const isPinned = document.getElementById('note-pin-toggle').checked;
            
            const selectedColorBtn = document.querySelector('.note-color-btn.selected');
            const color = selectedColorBtn ? selectedColorBtn.dataset.color : 'blue';
            
            let imagePath = null;
            if(!document.getElementById('note-image-preview-container').classList.contains('hidden')) {
                imagePath = document.getElementById('note-image-preview').dataset.basedata || null;
            }
            
            let audioPath = null;
            if(!document.getElementById('audio-preview-container').classList.contains('hidden')) {
                audioPath = document.getElementById('note-audio-preview').src;
            }
            
            await AppState.saveOrUpdateNote(id ? id : null, title, content, imagePath, audioPath, isPinned, color);
            closeModals();
        } catch(err) {
            console.error(err);
            alert("Not kaydedilirken bir hata oluştu: " + err.message);
        }
    };

    // Share & Export Listeners
    document.getElementById('btn-share-note').onclick = () => {
        const id = document.getElementById('note-id-hidden').value;
        const note = AppState.notes.find(n => n.id === id);
        if(note) shareNote(note);
    };

    document.getElementById('btn-export-options').onclick = () => {
        const container = document.getElementById('export-action-sheet');
        container.classList.remove('hidden');
    };

    document.getElementById('btn-close-export').onclick = closeExportMenu;
    document.getElementById('export-pdf-btn').onclick = () => exportNoteFormat('pdf');
    document.getElementById('export-doc-btn').onclick = () => exportNoteFormat('doc');
    document.getElementById('export-txt-btn').onclick = () => exportNoteFormat('txt');
}

function closeExportMenu() {
    document.getElementById('export-action-sheet').classList.add('hidden');
}

async function shareNote(note) {
    if (navigator.share) {
        try {
            const shareData = {
                title: note.title,
                text: note.content,
                url: window.location.href // Fallback if no real URL yet
            };

            const filesToShare = [];
            
            // Handle image/pdf share
            if(note.imagePath) {
                try {
                    const imgFile = dataURLtoFile(note.imagePath, "not_eki.png");
                    filesToShare.push(imgFile);
                } catch(e) { console.error("Resim paylaşıma eklenemedi:", e); }
            }

            // Handle audio share
            if(note.audioPath) {
                try {
                    const audioFile = dataURLtoFile(note.audioPath, "ses_kaydi.webm");
                    filesToShare.push(audioFile);
                } catch(e) { console.error("Ses kaydı paylaşıma eklenemedi:", e); }
            }

            // Try to share with files if supported
            if (filesToShare.length > 0 && navigator.canShare && navigator.canShare({ files: filesToShare })) {
                shareData.files = filesToShare;
            }

            await navigator.share(shareData);
        } catch (err) {
            console.log('Paylaşım iptal edildi veya hata oluştu:', err);
        }
    } else {
        alert("Tarayıcınız paylaşım özelliğini desteklemiyor. GitHub Pages üzerinden (https) test etmenizi öneririm.");
    }
}

function dataURLtoFile(dataurl, filename) {
    var arr = dataurl.split(','),
        mime = arr[0].match(/:(.*?);/)[1],
        bstr = atob(arr[1]), 
        n = bstr.length, 
        u8arr = new Uint8Array(n);
    while(n--){ u8arr[n] = bstr.charCodeAt(n); }
    return new File([u8arr], filename, {type:mime});
}

async function exportNoteFormat(format) {
    const id = document.getElementById('note-id-hidden').value;
    const note = AppState.notes.find(n => n.id === id);
    if(!note) return;

    closeExportMenu();

    const title = note.title || "Adsız Not";
    const dateStr = new Date(note.date).toLocaleString('tr-TR');
    const content = note.content;

    if (format === 'txt') {
        const text = `${title}\n${dateStr}\n\n${content}`;
        const blob = new Blob([text], { type: 'text/plain' });
        downloadBlob(blob, `${title}.txt`);
    } else if (format === 'doc') {
        const header = `<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'><head><meta charset='utf-8'></head><body>`;
        const footer = "</body></html>";
        let imageHTML = "";
        if(note.imagePath && !note.imagePath.includes('pdf')) {
            imageHTML = `<div style="text-align:center;"><img src="${note.imagePath}" width="500"></div>`;
        }
        let audioInfo = note.audioPath ? `<p style="color:red;"><b>[ Ses kaydı mevcuttur ]</b></p>` : "";
        const html = `${header}<h1>${title}</h1><p><i>${dateStr}</i></p><hr>${imageHTML}<div style="white-space:pre-wrap">${content}</div>${audioInfo}${footer}`;
        const blob = new Blob([html], { type: 'application/msword' });
        downloadBlob(blob, `${title}.doc`);
    } else if (format === 'pdf') {
        const temp = document.getElementById('export-template');
        document.getElementById('export-title').textContent = title;
        document.getElementById('export-date').textContent = dateStr;
        document.getElementById('export-content').textContent = content;
        
        const img = document.getElementById('export-image');
        if(note.imagePath && !note.imagePath.includes('pdf')) {
            img.src = note.imagePath;
            img.style.display = 'block';
        } else {
            img.style.display = 'none';
        }

        // Add audio indicator to PDF
        const oldInfo = document.getElementById('pdf-audio-info');
        if(oldInfo) oldInfo.remove();
        if(note.audioPath) {
            const info = document.createElement('div');
            info.id = 'pdf-audio-info';
            info.style = 'margin-top:20px; color:#FF3B30; font-weight:bold;';
            info.innerHTML = '<i class="ph ph-microphone"></i> Bu nota ait ses kaydı mevcuttur.';
            temp.appendChild(info);
            // Also download audio file separately
            const audioBlob = dataURLtoFile(note.audioPath, `${title}_ses.webm`);
            downloadBlob(audioBlob, `${title}_ses.webm`);
        }

        const opt = {
            margin: [0.5, 0.5],
            filename: `${title}.pdf`,
            image: { type: 'jpeg', quality: 0.98 },
            html2canvas: { scale: 2 },
            jsPDF: { unit: 'in', format: 'a4', orientation: 'portrait' }
        };
        
        html2pdf().from(temp).set(opt).save();
    }
}

function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
}

function openNoteSheet(existingNote) {
    document.getElementById('note-id-hidden').value = existingNote ? existingNote.id : '';
    document.getElementById('note-title-input').value = existingNote ? existingNote.title : '';
    document.getElementById('note-content-input').value = existingNote ? existingNote.content : '';
    document.getElementById('note-pin-toggle').checked = existingNote ? existingNote.isPinned : false;
    document.getElementById('note-sheet-title').textContent = existingNote ? "Not Detayı" : "Yeni Not";

    // Show share/export buttons only for existing notes
    if(existingNote) {
        document.getElementById('btn-share-note').classList.remove('hidden');
        document.getElementById('btn-export-options').classList.remove('hidden');
    } else {
        document.getElementById('btn-share-note').classList.add('hidden');
        document.getElementById('btn-export-options').classList.add('hidden');
    }
    
    const color = existingNote ? existingNote.noteColor : 'blue';
    document.querySelectorAll('.note-color-btn').forEach(b => {
        if(b.dataset.color === color) b.classList.add('selected');
        else b.classList.remove('selected');
    });
    
    const imgData = existingNote ? existingNote.imagePath : null;
    if(imgData) {
        document.getElementById('note-image-preview').dataset.basedata = imgData;
        if (imgData.includes('application/pdf')) {
            document.getElementById('note-image-preview').style.display = 'none';
            document.getElementById('note-file-name').textContent = '📄 Belge Eklendi';
            document.getElementById('note-file-name').style.display = 'block';
        } else {
            document.getElementById('note-image-preview').src = imgData;
            document.getElementById('note-image-preview').style.display = 'block';
            document.getElementById('note-file-name').style.display = 'none';
        }
        document.getElementById('note-image-preview-container').classList.remove('hidden');
    } else {
        document.getElementById('note-image-preview').src = '';
        delete document.getElementById('note-image-preview').dataset.basedata;
        document.getElementById('note-image-preview-container').classList.add('hidden');
    }
    
    const auData = existingNote ? existingNote.audioPath : null;
    if(auData) {
         document.getElementById('note-audio-preview').src = auData;
         document.getElementById('audio-preview-container').classList.remove('hidden');
    } else {
         document.getElementById('note-audio-preview').removeAttribute('src');
         document.getElementById('audio-preview-container').classList.add('hidden');
    }
    
    openModal('sheet-add-note');
}

function openModal(id) {
    const container = document.getElementById('modal-container');
    container.classList.remove('hidden');
    document.querySelectorAll('.sheet').forEach(s => s.classList.add('hidden'));
    document.getElementById(id).classList.remove('hidden');
    // little delay to allow display:block to catch before transform
    setTimeout(() => { container.classList.add('show'); }, 10);
}
function closeModals() {
    document.getElementById('modal-container').classList.add('hidden');
    document.querySelectorAll('.sheet').forEach(s => s.classList.add('hidden'));
}
