# Installation ADB App Manager
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ADB Application Manager - Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si on est dans le bon dossier
if (Test-Path "package.json") {
    Write-Host "[OK] Dossier détecté" -ForegroundColor Green
} else {
    Write-Host "[ERREUR] Lancez ce script dans le dossier adb-app-manager" -ForegroundColor Red
    pause
    exit
}

Write-Host "[1/2] Création de main.js..." -ForegroundColor Yellow

$mainJs = @'
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
    }
  });
  mainWindow.loadFile('index.html');
}

app.whenReady().then(createWindow);
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });

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
    if (lines.length === 0) return { success: false, error: 'Aucun appareil connecté' };
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
        packages.push({ name: packageName.trim(), label: label.trim(), path: apkPath.trim(), system: isSystem });
      }
    }
    return { success: true, packages };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

ipcMain.handle('list-running', async () => {
  try {
    const { stdout } = await execPromise('adb shell ps', { maxBuffer: 1024 * 1024 * 5 });
    const lines = stdout.split('\n');
    const running = [];
    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length > 8) {
        const processName = parts[8];
        if (processName && processName.includes('.')) running.push(processName);
      }
    }
    return { success: true, running: [...new Set(running)] };
  } catch (error) {
    return { success: false, error: error.message };
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
'@

Set-Content -Path "main.js" -Value $mainJs -Encoding UTF8

Write-Host "[2/2] Création de index.html..." -ForegroundColor Yellow

# Le fichier HTML est trop long pour PowerShell, on le télécharge
$indexHtml = Invoke-WebRequest -Uri "https://pastebin.com/raw/PLACEHOLDER" -UseBasicParsing -ErrorAction SilentlyContinue

if (-not $indexHtml) {
    Write-Host "[INFO] Création manuelle de index.html..." -ForegroundColor Yellow
    
    # Créer une version simplifiée
    $indexHtml = @'
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>ADB App Manager</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;background:linear-gradient(135deg,#1e1e2e,#2d1b69);color:#fff;padding:20px}.container{max-width:1400px;margin:0 auto}h1{text-align:center;margin-bottom:30px}button{padding:12px 24px;margin:5px;border:none;border-radius:8px;cursor:pointer;font-weight:600}.btn-primary{background:#7c3aed;color:#fff}.btn-success{background:#10b981;color:#fff}.btn-danger{background:#ef4444;color:#fff}#appContent{background:rgba(255,255,255,0.1);padding:20px;border-radius:15px;margin-top:20px}</style>
</head><body><div class="container"><h1>🤖 ADB Application Manager</h1>
<button class="btn-primary" onclick="checkADB()">Vérifier ADB</button>
<button class="btn-success" onclick="checkDevices()" id="checkDeviceBtn">Vérifier appareil</button>
<button class="btn-primary" onclick="loadApps()" id="loadAppsBtn">Charger apps</button>
<div id="appContent">Connectez votre appareil</div></div>
<script>
let apps=[];let deviceConnected=false;
async function checkADB(){const r=await window.adb.checkADB();alert(r.success?'ADB OK':'ADB non trouvé')}
async function checkDevices(){const r=await window.adb.checkDevices();deviceConnected=r.success;alert(r.success?'Appareil connecté':'Aucun appareil')}
async function loadApps(){if(!deviceConnected)return alert('Connectez un appareil');const r=await window.adb.listPackages({});apps=r.packages||[];document.getElementById('appContent').innerHTML=apps.map(a=>`<div>${a.label} (${a.name})</div>`).join('')}
</script></body></html>
'@
    Set-Content -Path "index.html" -Value $indexHtml -Encoding UTF8
    Write-Host "[ATTENTION] index.html simplifié créé. Copiez la version complète depuis l'artifact!" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation terminée!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prochaines étapes:" -ForegroundColor Yellow
Write-Host "1. npm install" -ForegroundColor White
Write-Host "2. npm start" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANT: Copiez le contenu complet de l'artifact 'index.html'" -ForegroundColor Red
Write-Host ""
pause