'use babel';

import fs from 'fs';
import path from 'path';

export default class Options {

  constructor(homeFolder) {
    this.configFile = path.join(homeFolder, '.wakatime.cfg');
    this.internalConfigFile = path.join(homeFolder, '.wakatime-internal.cfg');
  }

  getSetting(section, key, internal, callback) {
    fs.readFile(
      this.getConfigFile(internal),
      'utf-8',
      (err, content) => {
        if (err) {
          if (callback) callback({error: new Error(`could not read ${this.getConfigFile(internal)}`), key: key, value: null});
        } else {
          let currentSection = '';
          let lines = content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            let line = lines[i];
            if (this.startsWith(line.trim(), '[') && this.endsWith(line.trim(), ']')) {
              currentSection = line
                .trim()
                .substring(1, line.trim().length - 1)
                .toLowerCase();
            } else if (currentSection === section) {
              let parts = line.split('=');
              let currentKey = parts[0].trim();
              if (currentKey === key && parts.length > 1) {
                callback({key: key, value: this.removeNulls(parts[1].trim())});
                return;
              }
            }
          }

          if (callback) callback({key: key, value: null});
        }
      },
    );
  }

  setSetting(section, key, val, internal) {
    fs.readFile(
      this.getConfigFile(internal),
      'utf-8',
      (err, content) => {
        // ignore errors because config file might not exist yet
        if (err) content = '';

        let contents = [];
        let currentSection = '';

        let found = false;
        let lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          let line = lines[i];
          if (this.startsWith(line.trim(), '[') && this.endsWith(line.trim(), ']')) {
            if (currentSection === section && !found) {
              contents.push(this.removeNulls(key + ' = ' + val));
              found = true;
            }
            currentSection = line
              .trim()
              .substring(1, line.trim().length - 1)
              .toLowerCase();
            contents.push(this.removeNulls(line));
          } else if (currentSection === section) {
            let parts = line.split('=');
            let currentKey = parts[0].trim();
            if (currentKey === key) {
              if (!found) {
                contents.push(this.removeNulls(key + ' = ' + val));
                found = true;
              }
            } else {
              contents.push(this.removeNulls(line));
            }
          } else {
            contents.push(this.removeNulls(line));
          }
        }

        if (!found) {
          if (currentSection !== section) {
            contents.push('[' + section + ']');
          }
          contents.push(this.removeNulls(key + ' = ' + val));
        }

        fs.writeFile(this.getConfigFile(internal), contents.join('\n'), err => {
          if (err) throw err;
        });
      },
    );
  }

  setSettings(section, internal, settings) {
    fs.readFile(
      this.getConfigFile(internal),
      'utf-8',
      (err, content) => {
        // ignore errors because config file might not exist yet
        if (err) content = '';

        let contents = [];
        let currentSection = '';

        const found = {};
        let lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          let line = lines[i];
          if (this.startsWith(line.trim(), '[') && this.endsWith(line.trim(), ']')) {
            if (currentSection === section) {
              settings.forEach(setting => {
                if (!found[setting.key]) {
                  contents.push(this.removeNulls(setting.key + ' = ' + setting.value));
                  found[setting.key] = true;
                }
              });
            }
            currentSection = line
              .trim()
              .substring(1, line.trim().length - 1)
              .toLowerCase();
            contents.push(this.removeNulls(line));
          } else if (currentSection === section) {
            let parts = line.split('=');
            let currentKey = parts[0].trim();
            let keepLineUnchanged = true;
            settings.forEach(setting => {
              if (currentKey === setting.key) {
                keepLineUnchanged = false;
                if (!found[setting.key]) {
                  contents.push(this.removeNulls(setting.key + ' = ' + setting.value));
                  found[setting.key] = true;
                }
              }
            });
            if (keepLineUnchanged) {
              contents.push(this.removeNulls(line));
            }
          } else {
            contents.push(this.removeNulls(line));
          }
        }

        settings.forEach(setting => {
          if (!found[setting.key]) {
            if (currentSection !== section) {
              contents.push('[' + section + ']');
              currentSection = section;
            }
            contents.push(this.removeNulls(setting.key + ' = ' + setting.value));
            found[setting.key] = true;
          }
        });

        fs.writeFile(this.getConfigFile(internal), contents.join('\n'), err => {
          if (err) throw err;
        });
      },
    );
  }

  getConfigFile(internal) {
    return internal ? this.internalConfigFile : this.configFile;
  }

  startsWith(outer, inner) {
    return outer.slice(0, inner.length) === inner;
  }

  endsWith(outer, inner) {
    return inner === '' || outer.slice(-inner.length) === inner;
  }

  removeNulls(s) {
    return s.replace(/\0/g, '');
  }
}
