'use babel'

/*
WakaTime
Description: Analytics for programmers.
Maintainer:  WakaTime <support@wakatime.com>
License:     BSD, see LICENSE for more details.
Website:     https://wakatime.com/
*/
import decompress from 'decompress';
import del from 'del';
import pathExists from 'path-exists';
import fs from 'fs';
import os from 'os';
import path from 'path';
import process from 'process';
import child_process from 'child_process';
import request from 'request';
import {decode} from 'ini';

import StatusBarTileView from './status-bar-tile-view';
import Logger from './logger';

// package-global attributes
let log = null;
let packageVersion = null;
let lastHeartbeat = 0;
let lastFile = '';
let lastTodayFetch = 0;
const fetchTodayInterval = 60000;
let cachedToday = '';
let statusBarIcon = null;
let pluginReady = false;
let settingChangedObserver = null
let statusBarTile = null

export function activate() {
    log = new Logger('WakaTime');
    if (atom.config.get('wakatime.debug')) {
      log.setLevel('DEBUG');
    }
    packageVersion = atom.packages.getLoadedPackage('wakatime').metadata.version;
    log.debug(`Initializing WakaTime v${packageVersion}...`);
    requestIdleCallback(delayedActivate, {timeout: 10000});
}

function delayedActivate() {
    setupConfigs();
    settingChangedObserver = atom.config.observe('wakatime', settingChangedHandler);
    checkCLI();
}

export function consumeStatusBar(statusBar) {
    statusBarIcon = new StatusBarTileView();
    statusBarIcon.init();
    statusBarTile = statusBar != null ? statusBar.addRightTile({item: statusBarIcon, priority: 300}) : undefined;

    // set status bar icon visibility
    if (atom.config.get('wakatime.showStatusBarIcon')) {
      statusBarIcon.show();
    } else {
      statusBarIcon.hide();
    }

    if (pluginReady) {
      statusBarIcon.setTitle('WakaTime ready');
      statusBarIcon.setStatus(cachedToday);
    }
}

export function deactivate() {
    if (statusBarTile != null) {
      statusBarTile.destroy();
    }
    if (statusBarIcon != null) {
      statusBarIcon.destroy();
    }
    (settingChangedObserver != null ? settingChangedObserver.dispose() : undefined);
}

function checkCLI() {
  if (!isCLIInstalled()) {
    installCLI(() => {
      log.debug('Finished installing wakatime-cli.');
      finishActivation();
    });
  } else {
    getLastCheckedForUpdates(lastChecked => {

      // only check for updates to wakatime-cli every 24 hours
      const hours = 24;

      const currentTime = Math.round((new Date).getTime() / 1000);
      const beenLongEnough = (lastChecked + (3600 * hours)) < currentTime;

      if (beenLongEnough || atom.config.get('wakatime.debug')) {
        setLastCheckedForUpdates(currentTime);
        isCLILatest(latest => {
          if (!latest) {
            installCLI(() => {
              log.debug('Finished installing wakatime-cli.');
              finishActivation();
            });
          } else {
            finishActivation();
          }
        });
      } else {
        finishActivation();
      }
    });
  }
};

function getLastCheckedForUpdates(callback) {
  const filePath = path.join(resourcesFolder(), 'last-checked-for-updates');
  if (fs.existsSync(filePath)) {
    return fs.readFile(filePath, 'utf-8', (err, contents) => {
      if (err != null) {
        if (callback != null) {
          callback(0);
        }
        return;
      }
      if (contents != null) {
        try {
          if (callback != null) {
            callback(parseInt(contents.trim(), 10) || 0);
          }
          return;
        } catch (error) {}
      }
      if (callback != null) {
        return callback(0);
      }
    });
  } else {
    if (callback != null) {
      return callback(0);
    }
  }
};

function setLastCheckedForUpdates(lastChecked) {
  const filePath = path.join(resourcesFolder(), 'last-checked-for-updates');
  fs.writeFile(filePath, lastChecked.toString(), {encoding: 'utf-8'}, err => {
    if (err != null) {
      log.debug('Unable to save last checked for updates timestamp.');
    }
  });
};

function finishActivation() {
  pluginReady = true;
  setupEventHandlers();

  // set status bar icon visibility
  if (atom.config.get('wakatime.showStatusBarIcon')) {
    if (statusBarIcon != null) {
      statusBarIcon.show();
    }
  } else {
    if (statusBarIcon != null) {
      statusBarIcon.hide();
    }
  }

  if (statusBarIcon != null) {
    statusBarIcon.setTitle('WakaTime ready');
  }
  if (statusBarIcon != null) {
    statusBarIcon.setStatus(cachedToday);
  }
  getToday();
  log.debug('Finished initializing WakaTime.');
};

function settingChangedHandler(settings, initial) {
  if (settings.showStatusBarIcon) {
    if (statusBarIcon != null) {
      statusBarIcon.show();
    }
  } else {
    if (statusBarIcon != null) {
      statusBarIcon.hide();
    }
  }
  if (atom.config.get('wakatime.debug')) {
    log.setLevel('DEBUG');
  } else {
    log.setLevel('INFO');
  }
  const apiKey = settings.apikey;
  if (isValidApiKey(apiKey)) {
    atom.config.set('wakatime.apikey', ''); // clear setting so it updates in UI
    atom.config.set('wakatime.apikey', 'Saved in your $WAKATIME_HOME/.wakatime.cfg file');
    saveApiKey(apiKey);
  } else if (initial) {
    atom.config.set('wakatime.apikey', ''); // clear setting so it updates in UI
    atom.config.set('wakatime.apikey', 'Enter your api key...');
  }
};

function saveApiKey(apiKey) {
  const configFile = path.join(getWakatimeHome(), '.wakatime.cfg');
  fs.readFile(configFile, 'utf-8', function(err, inp) {
    if (err != null) {
      log.debug('Error: could not read wakatime config file');
    }
    if (String.prototype.startsWith == null) { String.prototype.startsWith = function(s) { return this.slice(0, s.length) === s; }; }
    if (String.prototype.endsWith == null) {   String.prototype.endsWith = function(s) { return (s === '') || (this.slice(-s.length) === s); }; }
    const contents = [];
    let currentSection = '';
    let found = false;
    if (inp != null) {
      for (let line of inp.split('\n')) {
        if (line.trim().startsWith('[') && line.trim().endsWith(']')) {
          if ((currentSection === 'settings') && !found) {
            contents.push(`api_key = ${apiKey}`);
            found = true;
          }
          currentSection = line.trim().substring(1, line.trim().length - 1).toLowerCase();
          contents.push(line);
        } else if (currentSection === 'settings') {
          const parts = line.split('=');
          const currentKey = parts[0].trim();
          if (currentKey === 'api_key') {
            if (!found) {
              contents.push(`api_key = ${apiKey}`);
              found = true;
            }
          } else {
            contents.push(line);
          }
        } else {
          contents.push(line);
        }
      }
    }

    if (!found) {
      if (currentSection !== 'settings') {
        contents.push('[settings]');
      }
      contents.push(`api_key = ${apiKey}`);
    }

    fs.writeFile(configFile, contents.join('\n'), {encoding: 'utf-8'}, err2 => {
      if (err2 != null) {
        const msg = 'Error: could not write to wakatime config file';
        log.error(msg);
        if (statusBarIcon != null) {
          statusBarIcon.setStatus('Error');
        }
        return (statusBarIcon != null ? statusBarIcon.setTitle(msg) : undefined);
      }
    });
  });
};

function getWakatimeHome(){ return process.env['WAKATIME_HOME'] || process.env[process.platform === 'win32' ? 'USERPROFILE' : 'HOME'] || ''; }

function setupConfigs() {
  const configFile = path.join(getWakatimeHome(), '.wakatime.cfg');
  fs.readFile(configFile, 'utf-8', (err, configContent) => {
    if (err != null) {
      log.debug('Error: could not read wakatime config file');
      settingChangedHandler(atom.config.get('wakatime'), true);
      return;
    }
    const commonConfigs = decode(configContent);
    if ((commonConfigs != null) && (commonConfigs.settings != null) && isValidApiKey(commonConfigs.settings.api_key)) {
      atom.config.set('wakatime.apikey', ''); // clear setting so it updates in UI
      atom.config.set('wakatime.apikey', 'Saved in your $WAKATIME_HOME/.wakatime.cfg file');
    } else {
      settingChangedHandler(atom.config.get('wakatime'), true);
    }
  });
};

function isValidApiKey(key) {
  if ((key == null)) {
    return false;
  }
  const re = new RegExp('^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$', 'i');
  return re.test(key);
};

const enoughTimePassed = time => (lastHeartbeat + 120000) < time;

function setupEventHandlers(callback) { return atom.workspace.observeTextEditors(editor => {
  try {
    const buffer = editor.getBuffer();
    buffer.onDidSave(e => {
      const {
        file
      } = buffer;
      if ((file != null) && file) {
        let lineno = null;
        if (editor.cursors.length > 0) {
          lineno = editor.cursors[0].getCurrentLineBufferRange().end.row + 1;
        }
        return sendHeartbeat(file, lineno, true);
      }
    });
    buffer.onDidChange(e => {
      const {
        file
      } = buffer;
      if ((file != null) && file) {
        let lineno = null;
        if (editor.cursors.length > 0) {
          lineno = editor.cursors[0].getCurrentLineBufferRange().end.row + 1;
        }
        return sendHeartbeat(file, lineno);
      }
    });
    editor.onDidChangeCursorPosition(e => {
      const {
        file
      } = buffer;
      if ((file != null) && file) {
        let lineno = null;
        if (editor.cursors.length > 0) {
          lineno = editor.cursors[0].getCurrentLineBufferRange().end.row + 1;
        }
        return sendHeartbeat(file, lineno);
      }
    });
  } catch (error) {}
  if (callback != null) {
    return callback();
  }
})
};

function isCLIInstalled() { return fs.existsSync(cliLocation()); }

function isCLILatest(callback) {
  const args = ['--version'];
  return child_process.execFile(cliLocation(), args, (error, stdout, stderr) => {
    if ((error == null)) {
      const currentVersion = stdout.trim() + stderr.trim();
      log.debug(`Current wakatime-cli version is ${currentVersion}`);
      log.debug('Checking for updates to wakatime-cli...');
      return getLatestCliVersion(latestVersion => {
        if (currentVersion === latestVersion) {
          log.debug('wakatime-cli is up to date.');
          if (callback != null) {
            return callback(true);
          }
        } else {
          if (latestVersion != null) {
            log.debug(`Found an updated wakatime-cli v${latestVersion}`);
            if (callback != null) {
              return callback(false);
            }
          } else {
            log.debug('Unable to find latest wakatime-cli version.');
            if (callback != null) {
              return callback(true);
            }
          }
        }
      });
    } else {
      if (callback != null) {
        return callback(false);
      }
    }
  });
};

function getLatestCliVersion(callback) {
  const options = {
    strictSSL: !atom.config.get('wakatime.disableSSLCertVerify'),
    url: `${s3BucketUrl()}current_version.txt`
  };
  return request.get(options, (error, response, body) => {
    let version = null;
    if (!error && (response.statusCode === 200)) {
      version = body.trim();
    }
    if (callback != null) {
      return callback(version);
    }
  });
};

function resourcesFolder() { return __dirname; }

function cliLocation() {
  const ext = process.platform === 'win32' ? '.exe' : '';
  return path.join(resourcesFolder(), 'wakatime-cli', `wakatime-cli${ext}`);
};

function installCLI(callback) {
  log.debug('Downloading wakatime-cli...');
  if (statusBarIcon != null) {
    statusBarIcon.setStatus('downloading wakatime-cli...');
  }
  const url = `${s3BucketUrl()}wakatime-cli.zip`;
  const zipFile = path.join(resourcesFolder(), 'wakatime-cli.zip');
  downloadFile(url, zipFile, async () => {
    await extractCLI(zipFile)
    if (process.platform !== 'win32') {
      fs.chmodSync(cliLocation(), 0o755);
    }
    if (callback != null) {
      return callback();
    }
  });
};

async function extractCLI(zipFile) {
  log.debug('Extracting wakatime-cli.zip file...');
  if (statusBarIcon != null) {
    statusBarIcon.setStatus('extracting wakatime-cli...');
  }
  await removeCLI();
  await unzip(zipFile, resourcesFolder())
};

async function removeCLI() {
  try {
    await del([path.join(resourcesFolder(), 'wakatime-cli')], {force: true});
  } catch (e) {
    log.warn(e);
  }
};

async function unzip(file, outputDir) {
  if (await pathExists(file)) {
    try {
      await decompress(file, outputDir);
    } catch (e) {
      log.warn(e);
    }
    finally {
      try {
        await del([file], {force: true});
      } catch (err) {
        log.warn(err);
      }
    }
  }
};

function architecture() {
  if (os.arch().indexOf('32') > -1) { return '32'; }
  return '64';
};

function s3BucketUrl() {
  const prefix = 'https://wakatime-cli.s3-us-west-2.amazonaws.com/';
  const p = process.platform;
  if (p === 'darwin') { return `${prefix}mac-x86-64/`; }
  if (p === 'win32') { return `${prefix}windows-x86-${architecture()}/`; }
  return `${prefix}linux-x86-64/`;
};

function downloadFile(url, outputFile, callback) {
  const options = {
    strictSSL: !atom.config.get('wakatime.disableSSLCertVerify'),
    url
  };
  const r = request(options);
  const out = fs.createWriteStream(outputFile);
  r.pipe(out);
  r.on('end', () => out.on('finish', async () => {
    if (callback != null) {
      return await callback();
    }
  }));
};

function sendHeartbeat(file, lineno, isWrite) {
  if (!isCLIInstalled()) {
    return;
  }

  if (((file.path == null) || (file.path === undefined)) && ((file.getPath == null) || (file.getPath() === undefined))) {
    log.debug(`Skipping file because path does not exist: ${file.path}`);
    return;
  }

  const currentFile = file.path || file.getPath();

  if (fileIsIgnored(currentFile)) {
    log.debug(`Skipping file because path matches ignore pattern: ${currentFile}`);
    return;
  }

  const time = Date.now();
  if (isWrite || enoughTimePassed(time) || (lastFile !== currentFile)) {
    const args = ['--file', currentFile, '--plugin', `atom-wakatime/${packageVersion}`];
    if (isWrite) {
      args.push('--write');
    }
    if (lineno != null) {
      args.push('--lineno');
      args.push(lineno);
    }
    if (atom.config.get('wakatime.debug')) {
      args.push('--verbose');
    }
    if (atom.config.get('wakatime.disableSSLCertVerify')) {
      args.push('--no-ssl-verify');
    }

    // fix for wakatime/atom-wakatime#65
    args.push('--config');
    args.push(path.join(getWakatimeHome(), '.wakatime.cfg'));

    if (atom.project.contains(currentFile)) {
      for (let rootDir of atom.project.rootDirectories) {
        const {
          realPath
        } = rootDir;
        if (currentFile.indexOf(realPath) > -1) {
          args.push('--alternate-project');
          args.push(path.basename(realPath));
          break;
        }
      }
    }

    lastHeartbeat = time;
    lastFile = currentFile;

    const cli = cliLocation();
    log.debug(`${cli} ${args.join(' ')}`);
    executeHeartbeatProcess(cli, args, 0);
    return getToday();
  }
};

function executeHeartbeatProcess(binary, args, tries) {
  const max_retries = 5;
  try {
    const proc = child_process.execFile(binary, args, (error, stdout, stderr) => {
      if (error != null) {
        let msg, status, title;
        if ((stderr != null) && (stderr !== '')) {
          log.warn(stderr);
        }
        if ((stdout != null) && (stdout !== '')) {
          log.warn(stdout);
        }
        if (proc.exitCode === 102) {
          msg = null;
          status = null;
          title = 'WakaTime Offline, coding activity will sync when online.';
        } else if (proc.exitCode === 103) {
          msg = 'An error occured while parsing $WAKATIME_HOME/.wakatime.cfg. Check $WAKATIME_HOME/.wakatime.log for more info.';
          status = 'Error';
          title = msg;
        } else if (proc.exitCode === 104) {
          msg = 'Invalid API Key. Make sure your API Key is correct!';
          status = 'Error';
          title = msg;
        } else {
          msg = error;
          status = 'Error';
          title = `Unknown Error (${proc.exitCode}); Check your Dev Console and ~/.wakatime.log for more info.`;
        }

        if (msg != null) {
          log.warn(msg);
        }
        if (statusBarIcon != null) {
          statusBarIcon.setStatus(status);
        }
        return (statusBarIcon != null ? statusBarIcon.setTitle(title) : undefined);

      } else {
        if (statusBarIcon != null) {
          statusBarIcon.setStatus(cachedToday);
        }
        const today = new Date();
        return statusBarIcon != null ? statusBarIcon.setTitle(`Last heartbeat sent ${formatDate(today)}`) : undefined;
      }
    });
  } catch (e) {
    tries++;
    const retry_in = 2;
    if (tries < max_retries) {
      log.debug(`Failed to send heartbeat when executing wakatime-cli background process, will retry in ${retry_in} seconds...`);
      setTimeout(() => executeHeartbeatProcess(binary, args, tries)
      , retry_in * 1000);
    } else {
      log.error('Failed to send heartbeat when executing wakatime-cli background process.');
      throw e;
    }
  }
};

function getToday() {
  if (!isCLIInstalled()) {
    return;
  }

  const cutoff = Date.now() - fetchTodayInterval;
  if (lastTodayFetch > cutoff) {
    return;
  }
  lastTodayFetch = Date.now();

  const args = ['--today', '--plugin', `atom-wakatime/${packageVersion}`];
  if (atom.config.get('wakatime.disableSSLCertVerify')) {
    args.push('--no-ssl-verify');
  }
  args.push('--config');
  args.push(path.join(getWakatimeHome(), '.wakatime.cfg'));

  try {
    child_process.execFile(cliLocation(), args, (error, stdout, stderr) => {
      if (error != null) {
        if ((stderr != null) && (stderr !== '')) {
          log.debug(stderr);
        }
        if ((stdout != null) && (stdout !== '')) {
          log.debug(stderr);
        }
      } else {
        cachedToday = `Today: ${stdout}`;
        (statusBarIcon != null ? statusBarIcon.setStatus(cachedToday, true) : undefined);
      }
    });
  } catch (e) {
    log.debug(e);
  }
};

function fileIsIgnored(file) {
  if (endsWith(file, 'COMMIT_EDITMSG') || endsWith(file, 'PULLREQ_EDITMSG') || endsWith(file, 'MERGE_MSG') || endsWith(file, 'TAG_EDITMSG')) {
    return true;
  }
  const patterns = atom.config.get('wakatime.ignore');
  if ((patterns == null)) {
    return true;
  }

  let ignore = false;
  for (let pattern of patterns) {
    const re = new RegExp(pattern, 'gi');
    if (re.test(file)) {
      ignore = true;
      break;
    }
  }
  return ignore;
};

function endsWith(str, suffix) {
  if ((str != null) && (suffix != null)) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
  }
  return false;
};

function formatDate(date) {
  const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
  ];
  let ampm = 'AM';
  let hour = date.getHours();
  if (hour > 11) {
    ampm = 'PM';
    hour = hour - 12;
  }
  if (hour === 0) {
    hour = 12;
  }
  let minute = date.getMinutes();
  if (minute < 10) {
    minute = `0${minute}`;
  }
  return `${months[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()} ${hour}:${minute} ${ampm}`;
};
