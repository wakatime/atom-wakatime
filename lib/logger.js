'use babel'

export default class Logger {

  constructor(name) {
    this.levels = {
      'ERROR': 40,
      'WARN': 30,
      'INFO': 20,
      'DEBUG': 10
    };
    this.name = name;
    this.level = 'INFO';
  }

  setLevel(level) {
    try {
      level = level.toUpperCase();
    } catch (error) {}
    if ((this.levels[level] == null)) {
      const keys = [];
      for (let key in this.levels) {
        keys.push(key);
      }
      this._log('ERROR', `Level must be one of: ${keys.join(', ')}`);
      return;
    }
    this.level = level;
  }

  log(level, msg) {
    level = level.toUpperCase();
    if ((this.levels[level] != null) && (this.levels[level] >= this.levels[this.level])) {
      this._log(level, msg);
    }
  }

  _log(level, msg) {
    level = level.toUpperCase();
    const origLine = this.originalLine();
    if (origLine[0] != null) {
      msg = `[${origLine[0]}:${origLine[1]}] ${msg}`;
    }
    msg = `[${level}] ${msg}`;
    msg = `[${this.name}] ${msg}`;
    switch (level) {
      case 'DEBUG': return console.log(msg);
      case 'INFO': return console.log(msg);
      case 'WARN': return console.warn(msg);
      case 'ERROR': return console.error(msg);
    }
  }

  originalLine() {
    const e = new Error('dummy');
    let file = null;
    let line = null;
    let first = true;
    for (let s of e.stack.split('\n')) {
      if (!first) {
        if (s.indexOf('at Logger.') === -1) {
          const m = s.match(/\(?.+[\/\\]([^:]+):(\d+):\d+\)?$/);
          if (m != null) {
            file = m[1];
            line = m[2];
            break;
          }
        }
      }
      first = false;
    }
    return [file, line];
  }

  debug(msg) {
    this.log('DEBUG', msg);
  }

  info(msg) {
    this.log('INFO', msg);
  }

  warn(msg) {
    this.log('WARN', msg);
  }

  error(msg) {
    this.log('ERROR', msg);
  }
}
