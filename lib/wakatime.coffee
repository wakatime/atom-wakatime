###
WakaTime
Description: Analytics for programmers.
Maintainer:  WakaTime <support@wakatime.com>
License:     BSD, see LICENSE for more details.
Website:     https://wakatime.com/
###

# package-global attributes
log = null
packageVersion = null
lastHeartbeat = 0
lastFile = ''
statusBarIcon = null
pluginReady = false

# package dependencies
AdmZip = require 'adm-zip'
fs = require 'fs'
os = require 'os'
path = require 'path'
execFile = require('child_process').execFile
request = require 'request'
rimraf = require 'rimraf'
ini = require 'ini'

StatusBarTileView = require './status-bar-tile-view'
Logger = require './logger'

module.exports =
  activate: (state) ->
    log = new Logger('WakaTime')
    if atom.config.get 'wakatime.debug'
      log.setLevel('DEBUG')
    packageVersion = atom.packages.getLoadedPackage('wakatime').metadata.version
    log.debug 'Initializing WakaTime v' + packageVersion + '...'
    setupConfigs()
    @settingChangedObserver = atom.config.observe 'wakatime', settingChangedHandler

    isPythonInstalled((installed) ->
      if not installed
        if os.type() is 'Windows_NT'
          installPython(checkCLI)
        else
          window.alert('Please install Python (https://www.python.org/downloads/) and restart Atom to enable the WakaTime plugin.')
      else
        checkCLI()
    )

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
      statusBarIcon.setStatus()

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

    # only check for updates to wakatime-cli every 24 hours
    hours = 24

    lastInit = atom.config.get 'wakatime-hidden.lastInit'
    currentTime = Math.round (new Date).getTime() / 1000
    beenawhile = parseInt(lastInit, 10) + 3600 * hours < currentTime

    if not lastInit? or beenawhile or atom.config.get('wakatime.debug')
      atom.config.set 'wakatime-hidden.lastInit', currentTime
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

finishActivation = () ->
  pluginReady = true
  setupEventHandlers()

  # set status bar icon visibility
  if atom.config.get 'wakatime.showStatusBarIcon'
    statusBarIcon?.show()
  else
    statusBarIcon?.hide()

  statusBarIcon?.setTitle('WakaTime ready')
  statusBarIcon?.setStatus()
  log.debug 'Finished initializing WakaTime.'

settingChangedHandler = (settings) ->
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
    atom.config.set 'wakatime.apikey', 'Saved in your ~/.wakatime.cfg file'
    saveApiKey apiKey

saveApiKey = (apiKey) ->
  configFile = path.join getUserHome(), '.wakatime.cfg'
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

getUserHome = ->
  process.env[if process.platform == 'win32' then 'USERPROFILE' else 'HOME'] || ''

setupConfigs = ->
  configFile = path.join getUserHome(), '.wakatime.cfg'
  fs.readFile configFile, 'utf-8', (err, configContent) ->
    if err?
      log.debug 'Error: could not read wakatime config file'
      settingChangedHandler atom.config.get('wakatime')
      return
    commonConfigs = ini.decode configContent
    if commonConfigs? and commonConfigs.settings? and isValidApiKey(commonConfigs.settings.api_key)
      atom.config.set 'wakatime.apikey', '' # clear setting so it updates in UI
      atom.config.set 'wakatime.apikey', 'Saved in your ~/.wakatime.cfg file'
    else
      settingChangedHandler atom.config.get('wakatime')

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

isPythonInstalled = (callback) ->
  pythonLocation((result) ->
    callback(result?)
  )

pythonLocation = (callback, locations) ->
  if global.cachedPythonLocation?
    callback(global.cachedPythonLocation)
  else
    if not locations?
      locations = [
        __dirname + path.sep + 'python' + path.sep + 'pythonw',
        'pythonw',
        'python',
        '/usr/local/bin/python',
        '/usr/bin/python',
      ]
      i = 26
      while i < 50
        locations.push '\\python' + i + '\\pythonw'
        locations.push '\\Python' + i + '\\pythonw'
        i++
    args = ['--version']
    if locations.length is 0
      callback(null)
      return
    pattern = /\d+\.\d+/
    location = locations[0]
    execFile(location, args, (error, stdout, stderr) ->
      if not error?
        if stdout? and stdout.match(pattern) or stderr? and stderr.match(pattern)
          global.cachedPythonLocation = location
          callback(location)
      else
        locations.splice(0, 1)
        pythonLocation(callback, locations)
    )

installPython = (callback) ->
  pyVer = '3.5.1'
  arch = 'win32'
  if os.arch().indexOf('x64') > -1
    arch = 'amd64'
  url = 'https://www.python.org/ftp/python/' + pyVer + '/python-' + pyVer + '-embed-' + arch + '.zip'

  log.debug 'downloading python...'
  statusBarIcon?.setStatus('downloading python...')

  zipFile = __dirname + path.sep + 'python.zip'
  downloadFile(url, zipFile, ->

    log.debug 'extracting python...'
    statusBarIcon?.setStatus('extracting python...')

    unzip(zipFile, __dirname + path.sep + 'python', ->
      fs.unlink(zipFile)
      log.debug 'Finished installing python.'
      if callback?
        callback()
    )
  )

isCLIInstalled = () ->
  return fs.existsSync(cliLocation())

isCLILatest = (callback) ->
  pythonLocation((python) ->
    if python?
      args = [cliLocation(), '--version']
      execFile(python, args, (error, stdout, stderr) ->
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
                log.debug 'Unable to find latest wakatime-cli version from GitHub.'
                if callback?
                  callback(true)
          )
        else
          if callback?
            callback(false)
      )
    else
      if callback?
        callback(false)
  )

getLatestCliVersion = (callback) ->
  url = 'https://raw.githubusercontent.com/wakatime/wakatime/master/wakatime/__about__.py'
  request.get(url, (error, response, body) ->
    version = null
    if !error and response.statusCode == 200
      re = new RegExp(/__version_info__ = \('([0-9]+)', '([0-9]+)', '([0-9]+)'\)/g)
      for line in body.split('\n')
        match = re.exec(line)
        if match?
          version = match[1] + '.' + match[2] + '.' + match[3]
    if callback?
      callback(version)
  )

cliLocation = () ->
  dir = __dirname + path.sep + 'wakatime-master' + path.sep + 'wakatime' + path.sep + 'cli.py'
  return dir

installCLI = (callback) ->
  log.debug 'Downloading wakatime-cli...'
  statusBarIcon?.setStatus('downloading wakatime-cli...')
  url = 'https://github.com/wakatime/wakatime/archive/master.zip'
  zipFile = __dirname + path.sep + 'wakatime-master.zip'
  downloadFile(url, zipFile, ->
    extractCLI(zipFile, callback)
  )

extractCLI = (zipFile, callback) ->
  log.debug 'Extracting wakatime-master.zip file...'
  statusBarIcon?.setStatus('extracting wakatime-cli...')
  removeCLI(->
    unzip(zipFile, __dirname, callback)
  )

removeCLI = (callback) ->
  if fs.existsSync(__dirname + path.sep + 'wakatime-master')
    try
      rimraf(__dirname + path.sep + 'wakatime-master', ->
        if callback?
          callback()
      )
    catch e
      log.warn e
      if callback?
        callback()
  else
    if callback?
      callback()

downloadFile = (url, outputFile, callback) ->
  r = request(url)
  out = fs.createWriteStream(outputFile)
  r.pipe(out)
  r.on('end', ->
    out.on('finish', ->
      if callback?
        callback()
    )
  )

unzip = (file, outputDir, callback) ->
  if fs.existsSync(file)
    try
      zip = new AdmZip(file)
      zip.extractAllTo(outputDir, true)
    catch e
      log.warn e
    finally
      fs.unlink(file)
      if callback?
        callback()

sendHeartbeat = (file, lineno, isWrite) ->
  if not file.path? or file.path is undefined or fileIsIgnored(file.path)
    return

  time = Date.now()
  currentFile = file.path
  if isWrite or enoughTimePassed(time) or lastFile isnt currentFile
    pythonLocation (python) ->
      return unless python?
      args = [cliLocation(), '--file', currentFile, '--plugin', 'atom-wakatime/' + packageVersion]
      if isWrite
        args.push('--write')
      if lineno?
        args.push('--lineno')
        args.push(lineno)
      if atom.config.get 'wakatime.debug'
        args.push('--verbose')

      if atom.project.contains(file.path)
        currentFile = file.path
        for rootDir in atom.project.rootDirectories
          realPath = rootDir.realPath
          if currentFile.indexOf(realPath) > -1
            args.push('--alternate-project')
            args.push(path.basename(realPath))
            break

      log.debug python + ' ' + args.join(' ')

      proc = execFile(python, args, (error, stdout, stderr) ->
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
            msg = 'An error occured while parsing ~/.wakatime.cfg. Check ~/.wakatime.log for more info.'
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
          statusBarIcon?.setStatus()
          today = new Date()
          statusBarIcon?.setTitle('Last heartbeat sent ' + formatDate(today))
      )
      lastHeartbeat = time
      lastFile = file.path

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

debug = (callback) ->
  if fs.existsSync(__dirname + path.sep + 'wakatime-master')
    try
      rimraf(__dirname + path.sep + 'wakatime-master', ->
        if callback?
          callback()
      )
    catch e
      log.warn e
      if callback?
        callback()
  else
    if callback?
      callback()
