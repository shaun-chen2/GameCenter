const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  getGames: () => ipcRenderer.invoke('app:getGames'),
  saveGames: (games) => ipcRenderer.invoke('app:saveGames', games),
  importGames: () => ipcRenderer.invoke('dialog:import'),
  launch: (game) => ipcRenderer.invoke('app:launch', game),
  stop: (game) => ipcRenderer.invoke('app:stop', game),
  openLocation: (game) => ipcRenderer.invoke('app:openLocation', game),
  selectIcon: () => ipcRenderer.invoke('dialog:selectIcon'),
  setIcon: (game, srcPath) => ipcRenderer.invoke('app:setIcon', game, srcPath),
  removeIcon: (game) => ipcRenderer.invoke('app:removeIcon', game),
  onRunning: (cb) => ipcRenderer.on('app:running', (e, ids) => cb(ids))
});
