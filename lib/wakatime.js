'use babel'
/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
/*
WakaTime
Description: Analytics for programmers.
Maintainer:  WakaTime <support@wakatime.com>
License:     BSD, see LICENSE for more details.
Website:     https://wakatime.com/
*/
import AdmZip from 'adm-zip';
import fs from 'fs';
import os from 'os';
import path from 'path';
import process from 'process';
import child_process from 'child_process';
import request from 'request';
import rimraf from 'rimraf';
import ini from 'ini';

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

module.exports = {
  activate(state) {
    log = new Logger('WakaTime');
    if (atom.config.get('wakatime.debug')) {
      log.setLevel('DEBUG');
    }
    packageVersion = atom.packages.getLoadedPackage('wakatime').metadata.version;
    log.debug('Initializing WakaTime v' + packageVersion + '...');
    return requestIdleCallback(this.delayedActivate, {timeout: 10000});
  },

  delayedActivate() {
    loadDependencies();
    setupConfigs();
    this.settingChangedObserver = atom.config.observe('wakatime', settingChangedHandler);
    return checkCLI();
  },

  consumeStatusBar(statusBar) {
    statusBarIcon = new StatusBarTileView();
    statusBarIcon.init();
    this.statusBarTile = statusBar != null ? statusBar.addRightTile({item: statusBarIcon, priority: 300}) : undefined;

    // set status bar icon visibility
    if (atom.config.get('wakatime.showStatusBarIcon')) {
      statusBarIcon.show();
    } else {
      statusBarIcon.hide();
    }

    if (pluginReady) {
      statusBarIcon.setTitle('WakaTime ready');
      return statusBarIcon.setStatus(cachedToday);
    }
  },

  deactivate() {
    if (this.statusBarTile != null) {
      this.statusBarTile.destroy();
    }
    if (statusBarIcon != null) {
      statusBarIcon.destroy();
    }
    return (this.settingChangedObserver != null ? this.settingChangedObserver.dispose() : undefined);
  }
};

var checkCLI = function() {
  if (!isCLIInstalled()) {
    return installCLI(function() {
      log.debug('Finished installing wakatime-cli.');
      return finishActivation();
    });
  } else {
    return getLastCheckedForUpdates(function(lastChecked) {

      // only check for updates to wakatime-cli every 24 hours
      const hours = 24;

      const currentTime = Math.round((new Date).getTime() / 1000);
      const beenLongEnough = (lastChecked + (3600 * hours)) < currentTime;

      if (beenLongEnough || atom.config.get('wakatime.debug')) {
        setLastCheckedForUpdates(currentTime);
        return isCLILatest(function(latest) {
          if (!latest) {
            return installCLI(function() {
              log.debug('Finished installing wakatime-cli.');
              return finishActivation();
            });
          } else {
            return finishActivation();
          }
        });
      } else {
        return finishActivation();
      }
    });
  }
};

var getLastCheckedForUpdates = function(callback) {
  const filePath = path.join(resourcesFolder(), 'last-checked-for-updates');
  if (fs.existsSync(filePath)) {
    return fs.readFile(filePath, 'utf-8', function(err, contents) {
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

var setLastCheckedForUpdates = function(lastChecked) {
  const filePath = path.join(resourcesFolder(), 'last-checked-for-updates');
  return fs.writeFile(filePath, lastChecked.toString(), {encoding: 'utf-8'}, function(err) {
    if (err != null) {
      return log.debug('Unable to save last checked for updates timestamp.');
    }
  });
};

var finishActivation = function() {
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
  return log.debug('Finished initializing WakaTime.');
};

var settingChangedHandler = function(settings, initial) {
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
    return saveApiKey(apiKey);
  } else if (initial) {
    atom.config.set('wakatime.apikey', ''); // clear setting so it updates in UI
    return atom.config.set('wakatime.apikey', 'Enter your api key...');
  }
};

var saveApiKey = function(apiKey) {
  const configFile = path.join(getWakatimeHome(), '.wakatime.cfg');
  return fs.readFile(configFile, 'utf-8', function(err, inp) {
    if (err != null) {
      log.debug('Error: could not read wakatime config file');
    }
    if (String.prototype.startsWith == null) { String.prototype.startsWith = function(s) { return this.slice(0, s.length) === s; }; }
    if (String.prototype.endsWith == null) {   String.prototype.endsWith = function(s) { return (s === '') || (this.slice(-s.length) === s); }; }
    const contents = [];
    let currentSection = '';
    let found = false;
    if (inp != null) {
      for (let line of Array.from(inp.split('\n'))) {
        if (line.trim().startsWith('[') && line.trim().endsWith(']')) {
          if ((currentSection === 'settings') && !found) {
            contents.push('api_key = ' + apiKey);
            found = true;
          }
          currentSection = line.trim().substring(1, line.trim().length - 1).toLowerCase();
          contents.push(line);
        } else if (currentSection === 'settings') {
          const parts = line.split('=');
          const currentKey = parts[0].trim();
          if (currentKey === 'api_key') {
            if (!found) {
              contents.push('api_key = ' + apiKey);
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
      contents.push('api_key = ' + apiKey);
    }

    return fs.writeFile(configFile, contents.join('\n'), {encoding: 'utf-8'}, function(err2) {
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

var getWakatimeHome = () => process.env['WAKATIME_HOME'] || process.env[process.platform === 'win32' ? 'USERPROFILE' : 'HOME'] || '';

var setupConfigs = function() {
  const configFile = path.join(getWakatimeHome(), '.wakatime.cfg');
  return fs.readFile(configFile, 'utf-8', function(err, configContent) {
    if (err != null) {
      log.debug('Error: could not read wakatime config file');
      settingChangedHandler(atom.config.get('wakatime'), true);
      return;
    }
    const commonConfigs = ini.decode(configContent);
    if ((commonConfigs != null) && (commonConfigs.settings != null) && isValidApiKey(commonConfigs.settings.api_key)) {
      atom.config.set('wakatime.apikey', ''); // clear setting so it updates in UI
      return atom.config.set('wakatime.apikey', 'Saved in your $WAKATIME_HOME/.wakatime.cfg file');
    } else {
      return settingChangedHandler(atom.config.get('wakatime'), true);
    }
  });
};

var isValidApiKey = function(key) {
  if ((key == null)) {
    return false;
  }
  const re = new RegExp('^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$', 'i');
  return re.test(key);
};

const enoughTimePassed = time => (lastHeartbeat + 120000) < time;

var setupEventHandlers = callback => atom.workspace.observeTextEditors(function(editor) {
  try {
    const buffer = editor.getBuffer();
    buffer.onDidSave(function(e) {
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
    buffer.onDidChange(function(e) {
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
    editor.onDidChangeCursorPosition(function(e) {
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
});

var isCLIInstalled = () => fs.existsSync(cliLocation());

var isCLILatest = function(callback) {
  const args = ['--version'];
  return child_process.execFile(cliLocation(), args, function(error, stdout, stderr) {
    if ((error == null)) {
      const currentVersion = stdout.trim() + stderr.trim();
      log.debug('Current wakatime-cli version is ' + currentVersion);
      log.debug('Checking for updates to wakatime-cli...');
      return getLatestCliVersion(function(latestVersion) {
        if (currentVersion === latestVersion) {
          log.debug('wakatime-cli is up to date.');
          if (callback != null) {
            return callback(true);
          }
        } else {
          if (latestVersion != null) {
            log.debug('Found an updated wakatime-cli v' + latestVersion);
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

var getLatestCliVersion = function(callback) {
  const options = {
    strictSSL: !atom.config.get('wakatime.disableSSLCertVerify'),
    url: s3BucketUrl() + 'current_version.txt'
  };
  return request.get(options, function(error, response, body) {
    let version = null;
    if (!error && (response.statusCode === 200)) {
      version = body.trim();
    }
    if (callback != null) {
      return callback(version);
    }
  });
};

var resourcesFolder = () => __dirname;

var cliLocation = function() {
  const ext = process.platform === 'win32' ? '.exe' : '';
  return path.join(resourcesFolder(), 'wakatime-cli', 'wakatime-cli' + ext);
};

var installCLI = function(callback) {
  log.debug('Downloading wakatime-cli...');
  if (statusBarIcon != null) {
    statusBarIcon.setStatus('downloading wakatime-cli...');
  }
  const url = s3BucketUrl() + 'wakatime-cli.zip';
  const zipFile = path.join(resourcesFolder(), 'wakatime-cli.zip');
  return downloadFile(url, zipFile, () => extractCLI(zipFile, function() {
    if (process.platform !== 'win32') {
      fs.chmodSync(cliLocation(), 0o755);
    }
    if (callback != null) {
      return callback();
    }
  }));
};

var extractCLI = function(zipFile, callback) {
  log.debug('Extracting wakatime-cli.zip file...');
  if (statusBarIcon != null) {
    statusBarIcon.setStatus('extracting wakatime-cli...');
  }
  return removeCLI(() => unzip(zipFile, resourcesFolder(), callback));
};

var removeCLI = function(callback) {
  if (fs.existsSync(path.join(resourcesFolder(), 'wakatime-cli'))) {
    try {
      return rimraf(path.join(resourcesFolder(), 'wakatime-cli'), function() {
        if (callback != null) {
          return callback();
        }
      });
    } catch (e) {
      log.warn(e);
      if (callback != null) {
        return callback();
      }
    }
  } else {
    if (callback != null) {
      return callback();
    }
  }
};

var unzip = function(file, outputDir, callback) {
  if (fs.existsSync(file)) {
    try {
      const zip = new AdmZip(file);
      return zip.extractAllTo(outputDir, true);
    } catch (e) {
      return log.warn(e);
    }
    finally {
      fs.unlink(file, function(err) {
        if (err != null) {
          log.warn(err);
        }
        if (callback != null) {
          return callback();
        }
      });
    }
  }
};

const architecture = function() {
  if (os.arch().indexOf('32') > -1) { return '32'; }
  return '64';
};

var s3BucketUrl = function() {
  const prefix = 'https://wakatime-cli.s3-us-west-2.amazonaws.com/';
  const p = process.platform;
  if (p === 'darwin') { return prefix + 'mac-x86-64/'; }
  if (p === 'win32') { return prefix + 'windows-x86-' + architecture() + '/'; }
  return prefix + 'linux-x86-64/';
};

var downloadFile = function(url, outputFile, callback) {
  const options = {
    strictSSL: !atom.config.get('wakatime.disableSSLCertVerify'),
    url
  };
  const r = request(options);
  const out = fs.createWriteStream(outputFile);
  r.pipe(out);
  return r.on('end', () => out.on('finish', function() {
    if (callback != null) {
      return callback();
    }
  }));
};

var sendHeartbeat = function(file, lineno, isWrite) {
  if (!isCLIInstalled()) {
    return;
  }

  if (((file.path == null) || (file.path === undefined)) && ((file.getPath == null) || (file.getPath() === undefined))) {
    log.debug('Skipping file because path does not exist: ' + file.path);
    return;
  }

  const currentFile = file.path || file.getPath();

  if (fileIsIgnored(currentFile)) {
    log.debug('Skipping file because path matches ignore pattern: ' + currentFile);
    return;
  }

  const time = Date.now();
  if (isWrite || enoughTimePassed(time) || (lastFile !== currentFile)) {
    const args = ['--file', currentFile, '--plugin', 'atom-wakatime/' + packageVersion];
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
      for (let rootDir of Array.from(atom.project.rootDirectories)) {
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
    log.debug(cli + ' ' + args.join(' '));
    executeHeartbeatProcess(cli, args, 0);
    return getToday();
  }
};

var executeHeartbeatProcess = function(binary, args, tries) {
  const max_retries = 5;
  try {
    let proc;
    return proc = child_process.execFile(binary, args, function(error, stdout, stderr) {
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
          title = 'Unknown Error (' + proc.exitCode + '); Check your Dev Console and ~/.wakatime.log for more info.';
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
        return (statusBarIcon != null ? statusBarIcon.setTitle('Last heartbeat sent ' + formatDate(today)) : undefined);
      }
    });
  } catch (e) {
    tries++;
    const retry_in = 2;
    if (tries < max_retries) {
      log.debug('Failed to send heartbeat when executing wakatime-cli background process, will retry in ' + retry_in + ' seconds...');
      return setTimeout(() => executeHeartbeatProcess(binary, args, tries)
      , retry_in * 1000);
    } else {
      log.error('Failed to send heartbeat when executing wakatime-cli background process.');
      throw e;
    }
  }
};

var getToday = function() {
  if (!isCLIInstalled()) {
    return;
  }

  const cutoff = Date.now() - fetchTodayInterval;
  if (lastTodayFetch > cutoff) {
    return;
  }
  lastTodayFetch = Date.now();

  const args = ['--today', '--plugin', 'atom-wakatime/' + packageVersion];
  if (atom.config.get('wakatime.disableSSLCertVerify')) {
    args.push('--no-ssl-verify');
  }
  args.push('--config');
  args.push(path.join(getWakatimeHome(), '.wakatime.cfg'));

  try {
    let proc;
    return proc = child_process.execFile(cliLocation(), args, function(error, stdout, stderr) {
      if (error != null) {
        if ((stderr != null) && (stderr !== '')) {
          log.debug(stderr);
        }
        if ((stdout != null) && (stdout !== '')) {
          return log.debug(stderr);
        }
      } else {
        cachedToday = 'Today: ' + stdout;
        return (statusBarIcon != null ? statusBarIcon.setStatus(cachedToday, true) : undefined);
      }
    });
  } catch (e) {
    return log.debug(e);
  }
};

var fileIsIgnored = function(file) {
  if (endsWith(file, 'COMMIT_EDITMSG') || endsWith(file, 'PULLREQ_EDITMSG') || endsWith(file, 'MERGE_MSG') || endsWith(file, 'TAG_EDITMSG')) {
    return true;
  }
  const patterns = atom.config.get('wakatime.ignore');
  if ((patterns == null)) {
    return true;
  }

  let ignore = false;
  for (let pattern of Array.from(patterns)) {
    const re = new RegExp(pattern, 'gi');
    if (re.test(file)) {
      ignore = true;
      break;
    }
  }
  return ignore;
};

var endsWith = function(str, suffix) {
  if ((str != null) && (suffix != null)) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
  }
  return false;
};

var formatDate = function(date) {
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
    minute = '0' + minute;
  }
  return months[date.getMonth()] + ' ' + date.getDate() + ', ' + date.getFullYear() + ' ' + hour + ':' + minute + ' ' + ampm;
};
