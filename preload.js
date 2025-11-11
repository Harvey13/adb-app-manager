const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('adb', {
  checkADB: () => ipcRenderer.invoke('check-adb'),
  checkDevices: () => ipcRenderer.invoke('check-devices'),
  listPackages: (options) => ipcRenderer.invoke('list-packages', options),
  listRunning: () => ipcRenderer.invoke('list-running'),
  checkAppStatus: (packageName) => ipcRenderer.invoke('check-app-status', packageName),
  forceStop: (packageName) => ipcRenderer.invoke('force-stop', packageName),
  uninstallApp: (packageName) => ipcRenderer.invoke('uninstall-app', packageName),
  enableApp: (packageName) => ipcRenderer.invoke('enable-app', packageName),
  disableApp: (packageName) => ipcRenderer.invoke('disable-app', packageName),
  clearData: (packageName) => ipcRenderer.invoke('clear-data', packageName),
  launchApp: (packageName) => ipcRenderer.invoke('launch-app', packageName)
});
