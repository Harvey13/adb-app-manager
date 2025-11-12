const { app, BrowserWindow, ipcMain } = require('electron');
const { exec } = require('child_process');
const path = require('path');
const util = require('util');
const execPromise = util.promisify(exec);

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    icon: path.join(__dirname, 'icon.png')
  });

  mainWindow.loadFile('index.html');
  
  // Ouvrir DevTools avec F12 ou Ctrl+Shift+I
  mainWindow.webContents.on('before-input-event', (event, input) => {
    if (input.key === 'F12' || (input.control && input.shift && input.key === 'I')) {
      mainWindow.webContents.toggleDevTools();
    }
  });
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

ipcMain.handle('check-adb', async () => {
  try {
    const { stdout } = await execPromise('adb version');
    return { success: true, version: stdout.trim() };
  } catch (error) {
    return { success: false, error: 'ADB non trouvé. Installez Android Platform Tools.' };
  }
});

ipcMain.handle('check-devices', async () => {
  try {
    const { stdout } = await execPromise('adb devices');
    const lines = stdout.split('\n').filter(line => line.includes('\t'));
    
    if (lines.length === 0) {
      return { success: false, error: 'Aucun appareil connecté' };
    }
    
    const devices = lines.map(line => {
      const [id, status] = line.split('\t');
      return { id: id.trim(), status: status.trim() };
    });
    
    return { success: true, devices };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('list-packages', async (event, options = {}) => {
  try {
    let command = 'adb shell pm list packages -f';
    
    if (options.thirdParty) command += ' -3';
    if (options.system) command += ' -s';
    if (options.disabled) command += ' -d';
    if (options.enabled) command += ' -e';
    
    const { stdout } = await execPromise(command, { maxBuffer: 1024 * 1024 * 10 });
    const packages = [];
    
    const lines = stdout.split('\n').filter(line => line.startsWith('package:'));
    
    for (const line of lines) {
      const match = line.match(/package:(.+)=(.+)/);
      if (match) {
        const [, apkPath, packageName] = match;
        let label = packageName.split('.').pop();
        const isSystem = apkPath.includes('/system/') || apkPath.includes('/vendor/') || apkPath.includes('/product/');
        
        // Récupérer la taille de l'APK
        let size = 0;
        try {
          const sizeCmd = `adb shell "du -k '${apkPath}' 2>/dev/null | cut -f1"`;
          const { stdout: sizeOut } = await execPromise(sizeCmd);
          size = parseInt(sizeOut.trim()) || 0;
        } catch (e) {
          // Taille non disponible
        }
        
        packages.push({
          name: packageName.trim(),
          label: label.trim(),
          path: apkPath.trim(),
          system: isSystem,
          size: size
        });
      }
    }
    
    return { success: true, packages };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('list-running', async () => {
  try {
    // Récupérer les processus avec leur mémoire
    const { stdout } = await execPromise('adb shell "ps -A -o NAME,RSS"', { maxBuffer: 1024 * 1024 * 5 });
    const lines = stdout.split('\n');
    const running = {};
    
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      
      const parts = line.split(/\s+/);
      if (parts.length >= 2) {
        const processName = parts[0];
        const rss = parseInt(parts[1]) || 0; // RSS en KB
        
        if (processName && processName.includes('.')) {
          running[processName] = rss;
        }
      }
    }
    
    return { success: true, running };
  } catch (error) {
    // Fallback simple si la commande échoue
    try {
      const { stdout } = await execPromise('adb shell ps', { maxBuffer: 1024 * 1024 * 5 });
      const lines = stdout.split('\n');
      const running = {};
      
      for (const line of lines) {
        const parts = line.trim().split(/\s+/);
        if (parts.length > 8) {
          const processName = parts[8];
          if (processName && processName.includes('.')) {
            running[processName] = 0; // Pas d'info mémoire
          }
        }
      }
      
      return { success: true, running };
    } catch (e) {
      return { success: false, error: e.message };
    }
  }
});

ipcMain.handle('check-app-status', async (event, packageName) => {
  try {
    const { stdout } = await execPromise('adb shell pm list packages -d');
    const disabled = stdout.includes(packageName);
    return { success: true, enabled: !disabled };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('force-stop', async (event, packageName) => {
  try {
    await execPromise(`adb shell am force-stop ${packageName}`);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('uninstall-app', async (event, packageName) => {
  try {
    const { stdout } = await execPromise(`adb uninstall ${packageName}`);
    return { success: true, output: stdout };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('enable-app', async (event, packageName) => {
  try {
    await execPromise(`adb shell pm enable ${packageName}`);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('disable-app', async (event, packageName) => {
  try {
    await execPromise(`adb shell pm disable-user ${packageName}`);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('clear-data', async (event, packageName) => {
  try {
    await execPromise(`adb shell pm clear ${packageName}`);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('launch-app', async (event, packageName) => {
  try {
    await execPromise(`adb shell monkey -p ${packageName} 1`);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});