###
WakaTime
Description: Analytics for programmers.
Maintainer:  WakaTime <support@wakatime.com>
License:     BSD, see LICENSE for more details.
Website:     https://wakatime.com/
###

AdmZip = require 'adm-zip'
fs = require 'fs'
os = require 'os'
path = require 'path'
execFile = require('child_process').execFile
request = require 'request'
rimraf = require 'rimraf'
ini = require 'ini'

packageVersion = null
unloadHandler = null
lastHeartbeat = 0
lastFile = ''
apiKey = null

module.exports =
  config:
    apikey:
      title: 'Api Key'
      description: 'Your secret key from https://wakatime.com/settings.'
      type: 'string'
      default: ''
      order: 1
    ignore:
      title: 'Exclude File Paths'
      description: 'Exclude these file paths from logging; POSIX regex patterns'
      type: 'array'
      default: ['^/var/', '^/tmp/', '^/private/', 'COMMIT_EDITMSG$', 'PULLREQ_EDITMSG$', 'MERGE_MSG$']
      items:
        type: 'string'
      order: 2

  activate: (state) ->
    packageVersion = atom.packages.getLoadedPackage('wakatime').metadata.version

    if not isCLIInstalled()
      installCLI(->
        console.log 'Finished installing wakatime cli.'
      )
    else
      isCLILatest((latest) ->
        if not latest
          installCLI(->
            console.log 'Finished installing wakatime cli.'
          )
      )
    isPythonInstalled((installed) ->
      if not installed
        atom.confirm
          message: 'WakaTime requires Python'
          detailedMessage: 'Let\'s download and install Python now?'
          buttons:
            OK: -> installPython()
            Cancel: -> window.alert('Please install Python (https://www.python.org/downloads/) and restart Atom to enable the WakaTime plugin.')
    )
    cleanupOnUninstall()
    setupEventHandlers()
    setApiKey()

getUserHome = ->
  process.env[if process.platform == 'win32' then 'USERPROFILE' else 'HOME'] || ''

setApiKey = ->
  loadApiKey (err, key) ->
    if err
      console.log err.message
    else
      apiKey = key

loadApiKey = (cb) ->
  key = atom.config.get('wakatime.apikey')
  return cb(null, key) if key? && key.length > 0
  wakatimeConfigFile = path.join getUserHome(), '.wakatime.cfg'
  fs.readFile wakatimeConfigFile, 'utf-8', (err, configContent) ->
    return cb(new Error('could not read wakatime config')) if err?
    wakatimeConfig = ini.parse configContent
    key = wakatimeConfig?.settings?.api_key
    if key?
      cb null, key
    else
      cb new Error('wakatime key not found')

enoughTimePassed = (time) ->
  return lastHeartbeat + 120000 < time

cleanupOnUninstall = () ->
  if unloadHandler?
    unloadHandler.dispose()
    unloadHandler = null
  unloadHandler = atom.packages.onDidUnloadPackage((p) ->
    if p? and p.name == 'wakatime'
      removeCLI()
      if unloadHandler?
        unloadHandler.dispose()
        unloadHandler = null
  )

setupEventHandlers = () ->
  atom.workspace.observeTextEditors (editor) =>
    try
      buffer = editor.getBuffer()
      buffer.onDidSave (e) =>
        file = buffer.file
        if file? and file
          lineno = null
          if editor.cursors.length > 0
            lineno = editor.cursors[0].getCurrentLineBufferRange().end.row + 1
          sendHeartbeat(file, lineno, true)
      buffer.onDidChange (e) =>
        file = buffer.file
        if file? and file
          lineno = null
          if editor.cursors.length > 0
            lineno = editor.cursors[0].getCurrentLineBufferRange().end.row + 1
          sendHeartbeat(file, lineno)
      editor.onDidChangeCursorPosition (e) =>
        file = buffer.file
        if file? and file
          lineno = null
          if editor.cursors.length > 0
            lineno = editor.cursors[0].getCurrentLineBufferRange().end.row + 1
          sendHeartbeat(file, lineno)

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
        "pythonw",
        "python",
        "/usr/local/bin/python",
        "/usr/bin/python",
        "\\python37\\pythonw",
        "\\Python37\\pythonw",
        "\\python36\\pythonw",
        "\\Python36\\pythonw",
        "\\python35\\pythonw",
        "\\Python35\\pythonw",
        "\\python34\\pythonw",
        "\\Python34\\pythonw",
        "\\python33\\pythonw",
        "\\Python33\\pythonw",
        "\\python32\\pythonw",
        "\\Python32\\pythonw",
        "\\python31\\pythonw",
        "\\Python31\\pythonw",
        "\\python30\\pythonw",
        "\\Python30\\pythonw",
        "\\python27\\pythonw",
        "\\Python27\\pythonw",
        "\\python26\\pythonw",
        "\\Python26\\pythonw",
        "\\python37\\python",
        "\\Python37\\python",
        "\\python36\\python",
        "\\Python36\\python",
        "\\python35\\python",
        "\\Python35\\python",
        "\\python34\\python",
        "\\Python34\\python",
        "\\python33\\python",
        "\\Python33\\python",
        "\\python32\\python",
        "\\Python32\\python",
        "\\python31\\python",
        "\\Python31\\python",
        "\\python30\\python",
        "\\Python30\\python",
        "\\python27\\python",
        "\\Python27\\python",
        "\\python26\\python",
        "\\Python26\\python",
      ]
    args = ['--version']
    if locations.length is 0
      callback(null)
      return
    location = locations[0]
    execFile(location, args, (error, stdout, stderr) ->
      if not error?
        global.cachedPythonLocation = location
        callback(location)
      else
        locations.splice(0, 1)
        pythonLocation(callback, locations)
    )

installPython = () ->
  if os.type() is 'Windows_NT'
    pyVer = '3.5.0'
    arch = 'win32'
    if os.arch().indexOf('x64') > -1
      arch = 'amd64'
    url = 'https://www.python.org/ftp/python/' + pyVer + '/python-' + pyVer + '-embed-' + arch + '.zip'

    console.log 'Downloading python...'
    zipFile = __dirname + path.sep + 'python.zip'
    downloadFile(url, zipFile, ->

      console.log 'Extracting python...'
      unzip(zipFile, __dirname + path.sep + 'python', ->
          fs.unlink(zipFile)
          console.log 'Finished installing python.'
      )
    )
  else
    window.alert('WakaTime depends on Python. Install it from https://python.org/downloads then restart Atom.')

isCLIInstalled = () ->
  return fs.existsSync(cliLocation())

isCLILatest = (callback) ->
  pythonLocation((python) ->
    if python?
      args = [cliLocation(), '--version']
      execFile(python, args, (error, stdout, stderr) ->
        if not error?
          currentVersion = stderr.trim()
          console.log 'Current wakatime-cli version is ' + currentVersion
          console.log 'Checking for updates to wakatime-cli...'
          getLatestCliVersion((latestVersion) ->
            if currentVersion == latestVersion
              console.log 'wakatime-cli is up to date.'
              if callback?
                callback(true)
            else
              console.log 'Found an updated wakatime-cli v' + latestVersion
              if callback?
                callback(false)
          )
        else
          if callback?
            callback(false)
      )
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
  console.log 'Downloading wakatime cli...'
  url = 'https://github.com/wakatime/wakatime/archive/master.zip'
  zipFile = __dirname + path.sep + 'wakatime-master.zip'
  downloadFile(url, zipFile, ->
    extractCLI(zipFile, callback)
  )

extractCLI = (zipFile, callback) ->
  console.log 'Extracting wakatime-master.zip file...'
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
      console.warn e
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
      console.warn e
    finally
      fs.unlink(file)
      if callback?
        callback()

sendHeartbeat = (file, lineno, isWrite) ->
  time = Date.now()
  if isWrite or enoughTimePassed(time) or lastFile isnt file.path
    if not file.path? or file.path is undefined or fileIsIgnored(file.path)
      return
    pythonLocation (python) ->
      return unless python? && apiKey?
      args = [cliLocation(), '--file', file.path, '--key', apiKey, '--plugin', 'atom-wakatime/' + packageVersion]
      if isWrite
        args.push('--write')
      if lineno?
        args.push('--lineno')
        args.push(lineno)
      proc = execFile(python, args, (error, stdout, stderr) ->
        if error?
          if stderr? and stderr != ''
            console.warn stderr
          if stdout? and stdout != ''
            console.warn stdout
          if proc.exitCode == 102
            console.warn 'Warning: api error (102); Check your ~/.wakatime.log file for more details.'
          else if proc.exitCode == 103
            console.warn 'Warning: config parsing error (103); Check your ~/.wakatime.log file for more details.'
          else
            console.warn error
      )
      lastHeartbeat = time
      lastFile = file.path

fileIsIgnored = (file) ->
  if endsWith(file, 'COMMIT_EDITMSG') or endsWith(file, 'PULLREQ_EDITMSG') or endsWith(file, 'MERGE_MSG') or endsWith(file, 'TAG_EDITMSG')
    return true
  patterns = atom.config.get('wakatime.ignore')
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
