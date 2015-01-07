
AdmZip = require 'adm-zip'
fs = require 'fs'
os = require 'os'
path = require 'path'
process = require('child_process');
request = require 'request'

module.exports =

    activate: (state) ->
        window.VERSION = atom.packages.getLoadedPackage('wakatime').metadata.version

        if not isCLIInstalled()
            installCLI()
        isPythonInstalled((installed) ->
            if not installed
                installPython()
        )
        setupConfig()
        setupEventHandlers()
        console.log 'WakaTime v'+VERSION+' loaded.'
    
lastAction = 0
lastFile = ''
    
enoughTimePassed = (time) ->
    return lastAction + 120000 < time

setupConfig = () ->
    unless atom.config.get("wakatime.apikey")?
        defaults =
            apikey: ""
            ignore: ["^/var/", "^/tmp/", "^/private/"]
        atom.config.set("wakatime", defaults)

setupEventHandlers = () ->
    atom.workspace.eachEditor (editor) =>
        try
            buffer = editor.getBuffer()
            buffer.on 'saved', (e) =>
                file = e.file
                time = Date.now()
                sendHeartbeat(file, time, true)
            buffer.on 'changed', (e) =>
                item = atom.workspaceView.getActivePaneItem()
                if item? and item
                    buffer = item.getBuffer()
                    if buffer? and buffer and buffer.file?
                        file = buffer.file
                        if file? and file
                            time = Date.now()
                            if enoughTimePassed(time) or lastFile isnt file.path
                                sendHeartbeat(file, time)

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
                'pythonw',
                'python',
                '/usr/local/bin/python',
                "/usr/bin/python",
                '\\python37\\pythonw',
                '\\python36\\pythonw',
                '\\python35\\pythonw',
                '\\python34\\pythonw',
                '\\python33\\pythonw',
                '\\python32\\pythonw',
                '\\python31\\pythonw',
                '\\python30\\pythonw',
                '\\python27\\pythonw',
                '\\python26\\pythonw',
                '\\python37\\python',
                '\\python36\\python',
                '\\python35\\python',
                '\\python34\\python',
                '\\python33\\python',
                '\\python32\\python',
                '\\python31\\python',
                '\\python30\\python',
                '\\python27\\python',
                '\\python26\\python',
            ]
        args = ['--version']
        if locations.length is 0
            callback(null)
            return
        location = locations[0]
        process.execFile(location, args, (error, stdout, stderr) ->
            if not error?
                global.cachedPythonLocation = location
                callback(location)
            else
                locations.splice(0, 1)
                pythonLocation(callback, locations)
        )

installPython = () ->
    if os.type() is 'Windows_NT'
        url = 'https://www.python.org/ftp/python/3.4.2/python-3.4.2.msi';
        if os.arch().indexOf('x64') > -1
            url = "https://www.python.org/ftp/python/3.4.2/python-3.4.2.amd64.msi";
        console.log 'Downloading python...'
        msiFile = __dirname + path.sep + 'python.msi'
        downloadFile(url, msiFile, ->
            console.log 'Installing python...'
            args = ['/i', msiFile, '/norestart', '/qb!']
            process.execFile('msiexec', args, (error, stdout, stderr) ->
                if error?
                    console.warn error
                    window.alert('Error encountered while installing Python.')
                else
                    fs.unlink(msiFile)
                    console.log 'Finished installing python.'
            )
        )
    else
        window.alert('WakaTime depends on Python. Install it from https://python.org/downloads then restart Atom.')

isCLIInstalled = () ->
    return fs.existsSync(cliLocation())

cliLocation = () ->
    dir = __dirname + path.sep + 'wakatime-master' + path.sep + 'wakatime-cli.py'
    return dir

installCLI = (callback) ->
    console.log 'Downloading wakatime-cli...'
    url = 'https://github.com/wakatime/wakatime/archive/master.zip'
    zipFile = __dirname + path.sep + 'wakatime-cli.zip'
    downloadFile(url, zipFile, ->
        console.log 'Extracting wakatime-cli.zip file...'
        unzip(zipFile, __dirname, true)
        console.log 'Finished installing wakatime-cli.'
        if callback?
            callback()
    )

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

unzip = (file, outputDir, cleanup) ->
    zip = new AdmZip(file)
    zip.extractAllTo(outputDir, true)
    if cleanup
        fs.unlink(file)
    
sendHeartbeat = (file, time, isWrite) ->
    pythonLocation((python) ->
        if python?
            if not file.path? or file.path is undefined or fileIsIgnored(file.path)
                return
            apikey = atom.config.get("wakatime.apikey")
            unless apikey
                return

            args = [cliLocation(), '--file', file.path, '--key', apikey, '--plugin', 'atom-wakatime/' + VERSION]
            if isWrite
                args.push('--write')
            process.execFile(python, args, (error, stdout, stderr) ->
                if error?
                    console.warn error
                # else
                #     console.log(args)
            )
            lastAction = time
            lastFile = file.path
    )
    
fileIsIgnored = (file) ->
    patterns = atom.config.get("wakatime.ignore")
    ignore = false
    for pattern in patterns
        re = new RegExp(pattern, "gi")
        if re.test(file)
            ignore = true
            break
    return ignore
