class Logger

  constructor: (name) ->
    @levels =
      'ERROR': 40
      'WARN': 30
      'INFO': 20
      'DEBUG': 10
    @name = name
    @level = 'INFO'

  setLevel: (level) ->
    try
      level = level.toUpperCase()
    if not @levels[level]?
      keys = []
      for key of @levels
        keys.push key
      @_log 'ERROR', 'Level must be one of: ' + keys.join(', ')
      return
    @level = level

  log: (level, msg) ->
    level = level.toUpperCase()
    if @levels[level]? and @levels[level] >= @levels[@level]
      @_log level, msg

  _log: (level, msg) ->
    level = level.toUpperCase()
    origLine = @originalLine()
    if origLine[0]?
      msg = '[' + origLine[0] + ':' + origLine[1] + '] ' + msg
    msg = '[' + level + '] ' + msg
    msg = '[' + @name + '] ' + msg
    switch level
      when 'DEBUG' then console.log msg
      when 'INFO' then console.log msg
      when 'WARN' then console.warn msg
      when 'ERROR' then console.error msg

  originalLine: () ->
    e = new Error('dummy')
    file = null
    line = null
    first = true
    for s in e.stack.split('\n')
      if not first
        if s.indexOf('at Logger.') == -1
          m = s.match /\(?.+[\/\\]([^:]+):(\d+):\d+\)?$/
          if m?
            file = m[1]
            line = m[2]
            break
      first = false
    return [file, line]

  debug: (msg) ->
    @log 'DEBUG', msg

  info: (msg) ->
    @log 'INFO', msg

  warn: (msg) ->
    @log 'WARN', msg

  error: (msg) ->
    @log 'ERROR', msg

module.exports = Logger
