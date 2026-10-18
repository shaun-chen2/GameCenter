const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const os = require('os');

const isWin = process.platform === 'win32';
const DATA_FILE = path.join(app.getPath('userData'), 'games.json');
const STEAM_CANDIDATES = [
  'C:\\Program Files (x86)\\Steam\\steam.exe',
  'C:\\Program Files\\Steam\\steam.exe'
];

// 运行中的进程（仅 exe/jar/shortcut 可追踪；Steam 由 Steam 自己管理）
const running = new Map(); // gameId -> ChildProcess
let mainWindow = null;

function loadGames() {
  try {
    const data = fs.readFileSync(DATA_FILE, 'utf8');
    return JSON.parse(data);
  } catch (e) {
    return [];
  }
}

function saveGames(games) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(games, null, 2));
}

// 读取 .url 文件里的 InternetShortcut
function parseUrlFile(filePath) {
  try {
    const text = fs.readFileSync(filePath, 'utf8');
    const m = text.match(/URL\s*=\s*(.+)/i);
    return m ? m[1].trim() : null;
  } catch (e) {
    return null;
  }
}

// 解析 Windows .lnk 快捷方式（仅 Windows 有效），返回 { target, args }
function resolveLnk(filePath) {
  if (!isWin) return { target: filePath, args: '' };
  const ps = [
    '$ws = New-Object -ComObject WScript.Shell;',
    `$sc = $ws.CreateShortcut('${filePath.replace(/'/g, "''")}');`,
    'Write-Output $sc.TargetPath;',
    'Write-Output $sc.Arguments;'
  ].join(' ');
  try {
    const out = require('child_process')
      .execSync(`powershell -NoProfile -Command "${ps}"`, { encoding: 'utf8' });
    const lines = out.split(/\r?\n/).map(s => s.trim()).filter(s => s.length);
    return { target: lines[0] || filePath, args: lines[1] || '' };
  } catch (e) {
    return { target: filePath, args: '' };
  }
}

// 检测 Steam 安装路径
function findSteam() {
  if (!isWin) return null;
  for (const c of STEAM_CANDIDATES) {
    if (fs.existsSync(c)) return c;
  }
  return null;
}

// 解析一个导入项，返回 GameRecord（或 null 表示忽略）
function parseEntry(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const base = path.basename(filePath, ext);
  const id = require('crypto').randomUUID();
  if (ext === '.exe') {
    return { id, name: base, type: 'Windows App', target: filePath, sourcePath: filePath, appId: null, addedAt: Date.now() };
  }
  if (ext === '.jar') {
    return { id, name: base, type: 'Java', target: filePath, sourcePath: filePath, appId: null, addedAt: Date.now() };
  }
  if (ext === '.url') {
    const url = parseUrlFile(filePath) || '';
    const m = url.match(/steam:\/\/run\/(\d+)/i) || url.match(/[?&:]appid=(\d+)/i);
    if (m) {
      return { id, name: base, type: 'Steam', target: null, sourcePath: filePath, appId: m[1], addedAt: Date.now() };
    }
    return { id, name: base, type: 'Shortcut', target: url, sourcePath: filePath, appId: null, addedAt: Date.now() };
  }
  if (ext === '.lnk') {
    const { target, args } = resolveLnk(filePath);
    const t = (target || '').toLowerCase();
    if (t.includes('steam.exe')) {
      const m = args.match(/-applaunch\s+(\d+)/i) || target.match(/appid=(\d+)/i);
      const appId = m ? m[1] : null;
      if (appId) {
        return { id, name: base, type: 'Steam', target: null, sourcePath: filePath, appId, addedAt: Date.now() };
      }
    }
    return { id, name: base, type: 'Shortcut', target, sourcePath: filePath, appId: null, args, addedAt: Date.now() };
  }
  // 其它（文件夹等）当作通用应用入口
  return { id, name: base, type: 'App', target: filePath, sourcePath: filePath, appId: null, addedAt: Date.now() };
}

// 启动游戏
ipcMain.handle('app:launch', (event, game) => {
  if (game.type === 'Steam' && game.appId) {
    const steam = findSteam();
    if (steam) {
      const p = spawn(steam, ['-applaunch', String(game.appId)], { detached: true, stdio: 'ignore' });
      p.unref();
    } else {
      shell.openExternal(`steam://run/${game.appId}`);
    }
    return { ok: true, tracked: false };
  }
  let target = game.target;
  let args = [];
  if (game.type === 'Java' || path.extname(target || '').toLowerCase() === '.jar') {
    target = 'java';
    args = ['-jar', game.target];
  } else if (game.args) {
    args = game.args.split(/\s+/).filter(Boolean);
  }
  try {
    const p = spawn(target, args, { detached: true, stdio: 'ignore', shell: isWin });
    p.unref();
    running.set(game.id, p);
    p.on('exit', () => { running.delete(game.id); notifyRunning(); });
    p.on('error', () => { running.delete(game.id); notifyRunning(); });
    return { ok: true, tracked: true };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
});

ipcMain.handle('app:stop', (event, game) => {
  const p = running.get(game.id);
  if (p) { try { p.kill(); } catch (e) {} running.delete(game.id); notifyRunning(); return { ok: true }; }
  return { ok: false };
});

ipcMain.handle('app:openLocation', (event, game) => {
  const dir = path.dirname(game.sourcePath);
  shell.openPath(dir);
  return { ok: true };
});

ipcMain.handle('app:getGames', () => loadGames());

ipcMain.handle('app:saveGames', (event, games) => { saveGames(games); return { ok: true }; });

ipcMain.handle('dialog:import', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: '导入游戏',
    properties: ['openFile', 'multiSelections'],
    filters: [
      { name: '游戏 / 快捷方式', extensions: ['exe', 'lnk', 'jar', 'url'] },
      { name: '所有文件', extensions: ['*'] }
    ]
  });
  if (result.canceled || !result.filePaths.length) return [];
  const existing = loadGames();
  const added = [];
  for (const fp of result.filePaths) {
    if (existing.some(g => g.sourcePath === fp)) continue;
    const rec = parseEntry(fp);
    if (rec) added.push(rec);
  }
  if (added.length) {
    const all = existing.concat(added);
    saveGames(all);
  }
  return added;
});

function notifyRunning() {
  if (mainWindow) mainWindow.webContents.send('app:running', Array.from(running.keys()));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 920, height: 620,
    minWidth: 720, minHeight: 480,
    title: 'GameCenter',
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false }
  });
  mainWindow.loadFile('index.html');
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});
app.on('window-all-closed', () => { if (!isWin) app.quit(); });
