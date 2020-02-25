###
WakaTime
Description: Analytics for programmers.
Maintainer:  WakaTime <support@wakatime.com>
License:     BSD, see LICENSE for more details.
Website:     https://wakatime.com/
###

StatusBarTileView = require './status-bar-tile-view'
Logger = require './logger'

# dependencies lazy-loaded to improve startup time
fs = null
os = null
path = null
process = null
child_process = null
request = null
ini = null

# package-global attributes
log = null
packageVersion = null
lastHeartbeat = 0
lastFile = ''
lastTodayFetch = 0
fetchTodayInterval = 60000
cachedToday = ''
statusBarIcon = null
pluginReady = false

module.exports =
  activate: (state) ->
    log = new Logger('WakaTime')
    if atom.config.get 'wakatime.debug'
      log.setLevel('DEBUG')
    packageVersion = atom.packages.getLoadedPackage('wakatime').metadata.version
    log.debug 'Initializing WakaTime v' + packageVersion + '...'
    requestIdleCallback @delayedActivate, {timeout: 10000}

  delayedActivate: ->
    loadDependencies()
    setupConfigs()
    @settingChangedObserver = atom.config.observe 'wakatime', settingChangedHandler
    checkCLI()

  consumeStatusBar: (statusBar) ->
    statusBarIcon = new StatusBarTileView()
    statusBarIcon.init()
    @statusBarTile = statusBar?.addRightTile(item: statusBarIcon, priority: 300)

    # set status bar icon visibility
    if atom.config.get 'wakatime.showStatusBarIcon'
      statusBarIcon.show()
    else
      statusBarIcon.hide()

    if pluginReady
      statusBarIcon.setTitle('WakaTime ready')
      statusBarIcon.setStatus(cachedToday)

  deactivate: ->
    @statusBarTile?.destroy()
    statusBarIcon?.destroy()
    @settingChangedObserver?.dispose()

checkCLI = () ->
  if not isCLIInstalled()
    installCLI(->
      log.debug 'Finished installing wakatime-cli.'
      finishActivation()
    )
  else
    getLastCheckedForUpdates((lastChecked) ->

      # only check for updates to wakatime-cli every 24 hours
      hours = 24

      currentTime = Math.round (new Date).getTime() / 1000
      beenLongEnough = lastChecked + 3600 * hours < currentTime

      if beenLongEnough or atom.config.get('wakatime.debug')
        setLastCheckedForUpdates(currentTime)
        isCLILatest((latest) ->
          if not latest
            installCLI(->
              log.debug 'Finished installing wakatime-cli.'
              finishActivation()
            )
          else
            finishActivation()
        )
      else
        finishActivation()
    )

getLastCheckedForUpdates = (callback) ->
  filePath = path.join cliFolder(), 'last-checked-for-updates'
  if fs.existsSync(filePath)
    fs.readFile filePath, 'utf-8', (err, contents) ->
      if err?
        if callback?
          callback(0)
        return
      if contents?
        try
          if callback?
            callback(parseInt(contents.trim(), 10) or 0)
          return
      if callback?
        callback(0)
  else
    if callback?
      callback(0)

setLastCheckedForUpdates = (lastChecked) ->
  filePath = path.join cliFolder(), 'last-checked-for-updates'
  fs.writeFile filePath, lastChecked.toString(), {encoding: 'utf-8'}, (err) ->
    if err?
      log.debug 'Unable to save last checked for updates timestamp.'

finishActivation = () ->
  pluginReady = true
  setupEventHandlers()

  # set status bar icon visibility
  if atom.config.get 'wakatime.showStatusBarIcon'
    statusBarIcon?.show()
  else
    statusBarIcon?.hide()

  statusBarIcon?.setTitle('WakaTime ready')
  statusBarIcon?.setStatus(cachedToday)
  getToday()
  log.debug 'Finished initializing WakaTime.'

settingChangedHandler = (settings, initial) ->
  if settings.showStatusBarIcon
    statusBarIcon?.show()
  else
    statusBarIcon?.hide()
  if atom.config.get 'wakatime.debug'
    log.setLevel('DEBUG')
  else
    log.setLevel('INFO')
  apiKey = settings.apikey
  if isValidApiKey(apiKey)
    atom.config.set 'wakatime.apikey', '' # clear setting so it updates in UI
    atom.config.set 'wakatime.apikey', 'Saved in your $WAKATIME_HOME/.wakatime.cfg file'
    saveApiKey apiKey
  else if initial
    atom.config.set 'wakatime.apikey', '' # clear setting so it updates in UI
    atom.config.set 'wakatime.apikey', 'Enter your api key...'

saveApiKey = (apiKey) ->
  configFile = path.join getWakatimeHome(), '.wakatime.cfg'
  fs.readFile configFile, 'utf-8', (err, inp) ->
    if err?
      log.debug 'Error: could not read wakatime config file'
    String::startsWith ?= (s) -> @slice(0, s.length) == s
    String::endsWith   ?= (s) -> s == '' or @slice(-s.length) == s
    contents = []
    currentSection = ''
    found = false
    if inp?
      for line in inp.split('\n')
        if line.trim().startsWith('[') and line.trim().endsWith(']')
          if currentSection == 'settings' and not found
            contents.push('api_key = ' + apiKey)
            found = true
          currentSection = line.trim().substring(1, line.trim().length - 1).toLowerCase()
          contents.push(line)
        else if currentSection == 'settings'
          parts = line.split('=')
          currentKey = parts[0].trim()
          if currentKey == 'api_key'
            if not found
              contents.push('api_key = ' + apiKey)
              found = true
          else
            contents.push(line)
        else
          contents.push(line)

    if not found
      if currentSection != 'settings'
        contents.push('[settings]')
      contents.push('api_key = ' + apiKey)

    fs.writeFile configFile, contents.join('\n'), {encoding: 'utf-8'}, (err2) ->
      if err2?
        msg = 'Error: could not write to wakatime config file'
        log.error msg
        statusBarIcon?.setStatus('Error')
        statusBarIcon?.setTitle(msg)

getWakatimeHome = ->
  process.env['WAKATIME_HOME'] || process.env[if process.platform == 'win32' then 'USERPROFILE' else 'HOME'] || ''

loadDependencies = ->
  fs = require 'fs'
  os = require 'os'
  path = require 'path'
  process = require 'process'
  child_process = require 'child_process'
  request = require 'request'
  ini = require 'ini'

setupConfigs = ->
  configFile = path.join getWakatimeHome(), '.wakatime.cfg'
  fs.readFile configFile, 'utf-8', (err, configContent) ->
    if err?
      log.debug 'Error: could not read wakatime config file'
      settingChangedHandler atom.config.get('wakatime'), true
      return
    commonConfigs = ini.decode configContent
    if commonConfigs? and commonConfigs.settings? and isValidApiKey(commonConfigs.settings.api_key)
      atom.config.set 'wakatime.apikey', '' # clear setting so it updates in UI
      atom.config.set 'wakatime.apikey', 'Saved in your $WAKATIME_HOME/.wakatime.cfg file'
    else
      settingChangedHandler atom.config.get('wakatime'), true

isValidApiKey = (key) ->
  if not key?
    return false
  re = new RegExp('^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$', 'i')
  return re.test key

enoughTimePassed = (time) ->
  return lastHeartbeat + 120000 < time

setupEventHandlers = (callback) ->
  atom.workspace.observeTextEditors (editor) ->
    try
      buffer = editor.getBuffer()
      buffer.onDidSave (e) ->
        file = buffer.file
        if file? and file
          lineno = null
          if editor.cursors.length > 0
            lineno = editor.cursors[0].getCurrentLineBufferRange().end.row + 1
          sendHeartbeat(file, lineno, true)
      buffer.onDidChange (e) ->
        file = buffer.file
        if file? and file
          lineno = null
          if editor.cursors.length > 0
            lineno = editor.cursors[0].getCurrentLineBufferRange().end.row + 1
          sendHeartbeat(file, lineno)
      editor.onDidChangeCursorPosition (e) ->
        file = buffer.file
        if file? and file
          lineno = null
          if editor.cursors.length > 0
            lineno = editor.cursors[0].getCurrentLineBufferRange().end.row + 1
          sendHeartbeat(file, lineno)
    if callback?
      callback()

isCLIInstalled = () ->
  return fs.existsSync(cliLocation())

isCLILatest = (callback) ->
  args = ['--version']
  child_process.execFile(cliLocation(), args, (error, stdout, stderr) ->
    if not error?
      currentVersion = stderr.trim()
      log.debug 'Current wakatime-cli version is ' + currentVersion
      log.debug 'Checking for updates to wakatime-cli...'
      getLatestCliVersion((latestVersion) ->
        if currentVersion == latestVersion
          log.debug 'wakatime-cli is up to date.'
          if callback?
            callback(true)
        else
          if latestVersion?
            log.debug 'Found an updated wakatime-cli v' + latestVersion
            if callback?
              callback(false)
          else
            log.debug 'Unable to find latest wakatime-cli version.'
            if callback?
              callback(true)
      )
    else
      if callback?
        callback(false)
  )

getLatestCliVersion = (callback) ->
  options =
    strictSSL: not atom.config.get('wakatime.disableSSLCertVerify')
    url: s3BucketUrl() + 'current_version.txt'
  request.get(options, (error, response, body) ->
    version = null
    if !error and response.statusCode == 200
      version = body.trim()
    if callback?
      callback(version)
  )

cliFolder = () ->
  return __dirname

cliLocation = () ->
  ext = if process.platform == 'win32' then '.exe' else ''
  return path.join cliFolder(), 'wakatime-cli' + ext

installCLI = (callback) ->
  log.debug 'Downloading wakatime-cli...'
  statusBarIcon?.setStatus('downloading wakatime-cli...')
  ext = if process.platform == 'win32' then '.exe' else ''
  url = s3BucketUrl() + 'wakatime' + ext
  localFile = cliLocation()
  downloadFile(url, localFile, () ->
    if process.platform != 'win32'
      fs.chmodSync(localFile, 0o755)
    if callback?
      callback()
  )

architecture = () ->
  return '32' if os.arch().indexOf('32') > -1
  return '64'

s3BucketUrl = () ->
  prefix = 'https://wakatime-cli.s3-us-west-2.amazonaws.com/'
  p = process.platform
  return prefix + 'mac-x86-64/' if p == 'darwin'
  return prefix + 'windows-x86-' + architecture() + '/' if p == 'win32'
  return prefix + 'linux-x86-64/'

downloadFile = (url, outputFile, callback) ->
  options =
    strictSSL: not atom.config.get('wakatime.disableSSLCertVerify')
    url: url
  r = request(options)
  out = fs.createWriteStream(outputFile)
  r.pipe(out)
  r.on('end', ->
    out.on('finish', ->
      if callback?
        callback()
    )
  )

sendHeartbeat = (file, lineno, isWrite) ->
  if not isCLIInstalled()
    return

  if (not file.path? or file.path is undefined) and (not file.getPath? or file.getPath() is undefined)
    log.debug 'Skipping file because path does not exist: ' + file.path
    return

  currentFile = file.path or file.getPath()

  if fileIsIgnored(currentFile)
    log.debug 'Skipping file because path matches ignore pattern: ' + currentFile
    return

  time = Date.now()
  if isWrite or enoughTimePassed(time) or lastFile isnt currentFile
    args = ['--file', currentFile, '--plugin', 'atom-wakatime/' + packageVersion]
    if isWrite
      args.push('--write')
    if lineno?
      args.push('--lineno')
      args.push(lineno)
    if atom.config.get 'wakatime.debug'
      args.push('--verbose')
    if atom.config.get 'wakatime.disableSSLCertVerify'
      args.push('--no-ssl-verify')

    # fix for wakatime/atom-wakatime#65
    args.push('--config')
    args.push(path.join getUserHome(), '.wakatime.cfg')

    if atom.project.contains(currentFile)
      for rootDir in atom.project.rootDirectories
        realPath = rootDir.realPath
        if currentFile.indexOf(realPath) > -1
          args.push('--alternate-project')
          args.push(path.basename(realPath))
          break

    lastHeartbeat = time
    lastFile = currentFile

    cli = cliLocation()
    log.debug cli + ' ' + args.join(' ')
    executeHeartbeatProcess cli, args, 0
    getToday()

executeHeartbeatProcess = (binary, args, tries) ->
  max_retries = 5
  try
    proc = child_process.execFile(binary, args, (error, stdout, stderr) ->
      if error?
        if stderr? and stderr != ''
          log.warn stderr
        if stdout? and stdout != ''
          log.warn stdout
        if proc.exitCode == 102
          msg = null
          status = null
          title = 'WakaTime Offline, coding activity will sync when online.'
        else if proc.exitCode == 103
          msg = 'An error occured while parsing $WAKATIME_HOME/.wakatime.cfg. Check $WAKATIME_HOME/.wakatime.log for more info.'
          status = 'Error'
          title = msg
        else if proc.exitCode == 104
          msg = 'Invalid API Key. Make sure your API Key is correct!'
          status = 'Error'
          title = msg
        else
          msg = error
          status = 'Error'
          title = 'Unknown Error (' + proc.exitCode + '); Check your Dev Console and ~/.wakatime.log for more info.'

        if msg?
          log.warn msg
        statusBarIcon?.setStatus(status)
        statusBarIcon?.setTitle(title)

      else
        statusBarIcon?.setStatus(cachedToday)
        today = new Date()
        statusBarIcon?.setTitle('Last heartbeat sent ' + formatDate(today))
    )
  catch e
    tries++
    retry_in = 2
    if tries < max_retries
      log.debug 'Failed to send heartbeat when executing wakatime-cli background process, will retry in ' + retry_in + ' seconds...'
      setTimeout ->
        executeHeartbeatProcess(binary, args, tries)
      , retry_in * 1000
    else
      log.error 'Failed to send heartbeat when executing wakatime-cli background process.'
      throw e

getToday = () ->
  if not isCLIInstalled()
    return

  cutoff = Date.now() - fetchTodayInterval
  if lastTodayFetch > cutoff
    return
  lastTodayFetch = Date.now()

  args = ['--today', '--plugin', 'atom-wakatime/' + packageVersion]
  if atom.config.get 'wakatime.disableSSLCertVerify'
    args.push('--no-ssl-verify')
  args.push('--config')
  args.push(path.join getWakatimeHome(), '.wakatime.cfg')

  try
    proc = child_process.execFile(cliLocation(), args, (error, stdout, stderr) ->
      if error?
        if stderr? and stderr != ''
          log.debug stderr
        if stdout? and stdout != ''
          log.debug stderr
      else
        cachedToday = 'Today: ' + stdout
        statusBarIcon?.setStatus(cachedToday, true)
    )
  catch e
    log.debug e

fileIsIgnored = (file) ->
  if endsWith(file, 'COMMIT_EDITMSG') or endsWith(file, 'PULLREQ_EDITMSG') or endsWith(file, 'MERGE_MSG') or endsWith(file, 'TAG_EDITMSG')
    return true
  patterns = atom.config.get('wakatime.ignore')
  if not patterns?
    return true

  ignore = false
  for pattern in patterns
    re = new RegExp(pattern, 'gi')
    if re.test(file)
      ignore = true
      break
  return ignore

endsWith = (str, suffix) ->
  if str? and suffix?
    return str.indexOf(suffix, str.length - suffix.length) != -1
  return false

formatDate = (date) ->
  months = [
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
  ]
  ampm = 'AM'
  hour = date.getHours()
  if (hour > 11)
    ampm = 'PM'
    hour = hour - 12
  if (hour == 0)
    hour = 12
  minute = date.getMinutes()
  if (minute < 10)
    minute = '0' + minute
  return months[date.getMonth()] + ' ' + date.getDate() + ', ' + date.getFullYear() + ' ' + hour + ':' + minute + ' ' + ampm
