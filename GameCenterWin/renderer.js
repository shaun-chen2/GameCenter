const state = {
  games: [],
  selectedId: null,
  search: '',
  groupBy: 'none',
  viewMode: 'list',          // list / grid
  running: new Set(),
  steam: new Set()
};

const $ = (s) => document.querySelector(s);

/// 按名称哈希得到固定的封面渐变色（Electron 端无系统图标，用彩色方块占位）
function coverColor(name) {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  const hue = h % 360;
  return `linear-gradient(135deg, hsl(${hue} 65% 52%), hsl(${(hue + 40) % 360} 65% 42%))`;
}

function coverInitial(name) {
  return (name.trim()[0] || '#').toUpperCase();
}

/// 自定义图标的 file:// 地址（无则返回 null，调用方回退到彩色占位）
function iconSrc(g) {
  if (g.iconPath) return 'file://' + g.iconPath.replace(/\\/g, '/');
  return null;
}

/// 设置某游戏图标（按钮或拖拽共用），成功后更新列表并重渲染
async function setIconFor(g, srcPath) {
  const r = await window.api.setIcon(g, srcPath);
  if (r.ok) {
    const i = state.games.findIndex(x => x.id === g.id);
    if (i >= 0) state.games[i] = r.game;
    render();
  }
}

function render() {
  const list = $('#list');
  list.innerHTML = '';
  list.className = 'list';
  const q = state.search.trim().toLowerCase();
  let games = state.games.filter(g => !q || g.name.toLowerCase().includes(q));

  if (!games.length) {
    list.innerHTML = '<div class="section-title">暂无游戏</div>';
  } else if (state.viewMode === 'grid') {
    list.className = 'grid';
    const sorted = games.slice().sort((a, b) => a.name.localeCompare(b.name));
    for (const g of sorted) list.appendChild(cardEl(g));
  } else if (state.groupBy === 'none') {
    for (const g of games) list.appendChild(itemEl(g));
  } else if (state.groupBy === 'type') {
    const groups = {};
    for (const g of games) (groups[g.type] = groups[g.type] || []).push(g);
    for (const k of Object.keys(groups).sort()) {
      list.appendChild(sectionTitle(k));
      for (const g of groups[k]) list.appendChild(itemEl(g));
    }
  } else {
    const groups = {};
    for (const g of games) {
      const c = (g.name[0] || '#').toUpperCase();
      (groups[c] = groups[c] || []).push(g);
    }
    for (const k of Object.keys(groups).sort()) {
      list.appendChild(sectionTitle(k));
      for (const g of groups[k]) list.appendChild(itemEl(g));
    }
  }
  renderDetail();
}

function sectionTitle(t) {
  const d = document.createElement('div');
  d.className = 'section-title';
  d.textContent = t;
  return d;
}

/// 列表项（含自定义小图标 / 彩色占位）
function itemEl(g) {
  const d = document.createElement('div');
  d.className = 'item' + (g.id === state.selectedId ? ' active' : '');
  const ico = document.createElement('span');
  ico.className = 'ico';
  const src = iconSrc(g);
  if (src) {
    ico.style.backgroundImage = `url("${src}")`;
  } else {
    ico.style.background = coverColor(g.name);
    ico.textContent = coverInitial(g.name);
  }
  const dot = document.createElement('span');
  dot.className = 'dot' + ((state.running.has(g.id) || state.steam.has(g.id)) ? ' run' : '');
  const name = document.createElement('span');
  name.className = 'name';
  name.textContent = g.name;
  const type = document.createElement('span');
  type.className = 'type';
  type.textContent = g.type;
  d.append(ico, dot, name, type);
  d.onclick = () => { state.selectedId = g.id; render(); };
  return d;
}

/// 网格封面卡：自定义封面图 / 彩色方块（首字母）+ 名称 + 类型 + 运行中绿点
function cardEl(g) {
  const d = document.createElement('div');
  d.className = 'card';
  const run = state.running.has(g.id) || state.steam.has(g.id);

  const cover = document.createElement('div');
  cover.className = 'cover';
  const src = iconSrc(g);
  if (src) {
    cover.style.backgroundImage = `url("${src}")`;
    cover.style.backgroundSize = 'cover';
    cover.style.backgroundPosition = 'center';
    cover.textContent = '';
  } else {
    cover.style.background = coverColor(g.name);
    cover.textContent = coverInitial(g.name);
  }
  if (run) {
    const dot = document.createElement('span');
    dot.className = 'run';
    cover.appendChild(dot);
  }
  cover.addEventListener('dragover', e => { e.preventDefault(); cover.classList.add('drop'); });
  cover.addEventListener('dragleave', () => cover.classList.remove('drop'));
  cover.addEventListener('drop', e => {
    e.preventDefault(); cover.classList.remove('drop');
    const f = e.dataTransfer.files[0];
    if (f && f.path) setIconFor(g, f.path);
  });

  const row = document.createElement('div');
  row.className = 'row';
  const name = document.createElement('span');
  name.className = 'name';
  name.textContent = g.name;
  row.appendChild(name);

  const type = document.createElement('div');
  type.className = 'type';
  type.textContent = g.type;

  d.append(cover, row, type);
  d.onclick = () => { state.selectedId = g.id; render(); };
  return d;
}

function renderDetail() {
  const el = $('#detail');
  const g = state.games.find(x => x.id === state.selectedId);
  if (!g) { el.innerHTML = '<div class="empty">从左侧选择或导入一个游戏</div>'; return; }
  const isRun = state.running.has(g.id) || state.steam.has(g.id);
  const hsrc = iconSrc(g);
  const heroCoverHtml = hsrc
    ? `<div class="hero-cover" style="background-image:url('${hsrc}');background-size:cover;background-position:center"></div>`
    : `<div class="hero-cover" style="background:${coverColor(g.name)}">${escapeHtml(coverInitial(g.name))}</div>`;
  el.innerHTML = `
    <div class="hero">
      ${heroCoverHtml}
      <div class="hero-info">
        <h1>${escapeHtml(g.name)}</h1>
        <div>
          <span class="badge">${g.type}</span>
          ${isRun ? '<span class="badge running">运行中</span>' : ''}
        </div>
        <div class="hero-meta">添加于 ${new Date(g.addedAt).toLocaleString()}</div>
        <div class="row">
          ${isRun
            ? '<button class="btn small danger" id="stopBtn">停止</button>'
            : '<button class="btn small primary" id="launchBtn">启动</button>'}
          <button class="btn small" id="locBtn">打开所在位置</button>
          <button class="btn small" id="iconBtn">设置图标</button>
          ${g.iconPath ? '<button class="btn small" id="rmIconBtn">移除图标</button>' : ''}
          <button class="btn small danger" id="delBtn">移除</button>
        </div>
        <div class="status" id="status"></div>
      </div>
    </div>
    <div class="meta">
      <div><b>来源路径</b><br>${escapeHtml(g.sourcePath || '-')}</div>
      ${g.target ? `<div><b>启动目标</b><br>${escapeHtml(g.target)}</div>` : ''}
      ${g.appId ? `<div><b>Steam App ID</b><br>${escapeHtml(String(g.appId))}</div>` : ''}
      <div><b>导入时间</b><br>${new Date(g.addedAt).toLocaleString()}</div>
    </div>
  `;
  const launchBtn = $('#launchBtn');
  if (launchBtn) launchBtn.onclick = async () => {
    launchBtn.disabled = true;
    const r = await window.api.launch(g);
    launchBtn.disabled = false;
    const st = $('#status');
    if (r.ok) {
      st.textContent = r.tracked ? '已启动' : '已通过 Steam 启动';
      if (!r.tracked) state.steam.add(g.id); // Steam 由 Steam 自己管理，本地乐观标记
      render();
    } else {
      st.textContent = '启动失败：' + (r.error || '未知错误');
    }
  };
  const stopBtn = $('#stopBtn');
  if (stopBtn) stopBtn.onclick = async () => {
    await window.api.stop(g);
    state.running.delete(g.id);
    state.steam.delete(g.id);
    render();
  };
  $('#locBtn').onclick = () => window.api.openLocation(g);
  $('#iconBtn').onclick = async () => {
    const p = await window.api.selectIcon();
    if (p) await setIconFor(g, p);
  };
  const rmIconBtn = $('#rmIconBtn');
  if (rmIconBtn) rmIconBtn.onclick = async () => {
    const r = await window.api.removeIcon(g);
    if (r.ok) {
      const i = state.games.findIndex(x => x.id === g.id);
      if (i >= 0) state.games[i] = r.game;
      render();
    }
  };
  const hc = el.querySelector('.hero-cover');
  if (hc) {
    hc.addEventListener('dragover', e => { e.preventDefault(); hc.classList.add('drop'); });
    hc.addEventListener('dragleave', () => hc.classList.remove('drop'));
    hc.addEventListener('drop', e => {
      e.preventDefault(); hc.classList.remove('drop');
      const f = e.dataTransfer.files[0];
      if (f && f.path) setIconFor(g, f.path);
    });
  }
  $('#delBtn').onclick = async () => {
    state.games = state.games.filter(x => x.id !== g.id);
    await window.api.saveGames(state.games);
    state.selectedId = null;
    render();
  };
}

function escapeHtml(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

async function init() {
  state.games = await window.api.getGames();
  $('#search').oninput = (e) => { state.search = e.target.value; render(); };
  $('#groupBy').onchange = (e) => { state.groupBy = e.target.value; render(); };
  $('#importBtn').onclick = async () => {
    const added = await window.api.importGames();
    if (added && added.length) {
      state.games = state.games.concat(added);
      state.selectedId = added[added.length - 1].id;
    }
    render();
  };
  document.querySelectorAll('#viewToggle button').forEach(btn => {
    btn.onclick = () => {
      state.viewMode = btn.dataset.mode;
      document.querySelectorAll('#viewToggle button').forEach(b => b.classList.toggle('active', b === btn));
      render();
    };
  });
  window.api.onRunning((ids) => {
    state.running = new Set(ids);
    render();
  });
  render();
}

init();
