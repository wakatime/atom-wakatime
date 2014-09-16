
highlight = undefined

module.exports =

  activate: (state) ->
    window.VERSION = atom.packages.getLoadedPackage('wakatime').metadata.version
    highlight = require 'highlight.js'
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
        buffer = editor.getBuffer()
        buffer.on 'saved', (e) =>
            file = e.file
            time = Date.now()
            sendHeartbeat(file, time, true)
        buffer.on 'changed', (e) =>
            item = atom.workspaceView.getActivePaneItem()
            if item?
                buffer = item.getBuffer()
                if buffer? and buffer.file?
                    file = buffer.file
                    if file
                        time = Date.now()
                        if enoughTimePassed(time) or lastFile isnt file.path
                            sendHeartbeat(file, time)

sendHeartbeat = (file, time, isWrite) ->
    if file.path is undefined or fileIsIgnored(file.path)
        return
    apikey = atom.config.get("wakatime.apikey")
    unless apikey
        return
    ext = file.path.split('.').pop()
    language = ext if languageMap[ext]?
    unless language?
        language = ext if highlight.getLanguage(ext)? and languageMap[ext]?
        unless language?
            language = highlight.highlightAuto(file.cachedContents).language if file.cachedContents
    language = languageMap[language] if language? and languageMap[language]
    project = (if atom.project.path? then atom.project.path.split(/[\\\/]/).pop() else undefined)
    branch =  (if atom.project.repo and atom.project.repo.branch then atom.project.repo.branch.split('/').pop() else undefined)
    lines = (if file.cachedContents then file.cachedContents.split("\n").length else undefined)
    request = new XMLHttpRequest()
    request.open('POST', 'https://wakatime.com/api/v1/actions', true)
    request.setRequestHeader('Authorization', 'Basic ' + btoa(apikey))
    request.setRequestHeader('Content-Type', 'application/json')
    request.send(JSON.stringify(
        time: (time / 1000.0).toFixed(2)
        file: file.path
        project: project
        language: language
        is_write: (if isWrite then true else false)
        lines: lines
        plugin: 'atom-wakatime/' + VERSION
    ))
    lastAction = time
    lastFile = file.path
    
fileIsIgnored = (file) ->
    patterns = atom.config.get("wakatime.ignore")
    ignore = false
    for pattern in patterns
        re = new RegExp(pattern, "gi")
        if re.test(file)
            ignore = true
            break
    return ignore

languageMap =
    "1c": "1C"
    "actionscript": "ActionScript"
    "apache": "Apache Conf"
    "apacheconf": "Apache Conf"
    "applescript": "AppleScript"
    "as": "ActionScript"
    "asciidoc": "AsciiDoc"
    "autohotkey": "AutoHotkey"
    "avrasm": "AVR Assembler"
    "axapta": "Axapta"
    "bash": "Bash"
    "bat": "DOS"
    "brainfuck": "Brainfuck"
    "c": "C"
    "capnp": "Cap'n Proto"
    "capnproto": "Cap'n Proto"
    "clj": "Clojure"
    "clojure": "Clojure"
    "cmake": "CMake"
    "cmake.in": "CMake"
    "cmd": "DOS"
    "coffee": "CoffeeScript"
    "coffeescript": "CoffeeScript"
    "cpp": "C++"
    "c++": "C++"
    "cs": "C#"
    "csharp": "C#"
    "cson": "CoffeeScript"
    "css": "CSS"
    "d": "D"
    "dart": "Dart"
    "delphi": "Delphi"
    "diff": "Diff"
    "django": "HTML"
    "dos": "DOS"
    "dst": "Dust"
    "dust": "Dust"
    "elixir": "Elixir"
    "erl": "Erlang"
    "erlang-repl": "Erlang"
    "erlang": "Erlang"
    "fix": "FIX"
    "fs": "F#"
    "fsharp": "F#"
    "gcode": "G-code"
    "gherkin": "Gherkin"
    "glsl": "GLSL"
    "go": "Go"
    "golang": "Go"
    "gradle": "Gradle"
    "groovy": "Groovy"
    "h++": "C++"
    "haml": "Haml"
    "handlebars": "Handlebars"
    "haskell": "Haskell"
    "haxe": "Haxe"
    "html": "HTML"
    "http": "HTTP"
    "iced": "CoffeeScript"
    "ini": "INI"
    "java": "Java"
    "javascript": "JavaScript"
    "jinja": "HTML"
    "json": "JSON"
    "lasso": "Lasso"
    "less": "LESS"
    "lisp": "Lisp"
    "livecodeserver": "LiveCode"
    "lua": "Lua"
    "m": "Objective-C"
    "mm": "Objective-C"
    "makefile": "Makefile"
    "markdown": "Markdown"
    "mathematica": "Mathematica"
    "matlab": "Matlab"
    "mel": "MEL"
    "mizar": "Mizar"
    "monkey": "Monkey"
    "nc": "nesC"
    "nesc": "nesC"
    "nginx": "Nginx Conf"
    "nginxconf": "Nginx Conf"
    "nimrod": "Nimrod"
    "nix": "Nix"
    "nsis": "NSIS"
    "objectivec": "Objective-C"
    "ocaml": "OCaml"
    "osascript": "AppleScript"
    "oxygene": "Oxygene"
    "parser3": "Parser3"
    "patch": "Diff"
    "perl": "Perl"
    "php": "PHP"
    "profile": "Python profile"
    "protobuf": "Protocol Buffers"
    "puppet": "Puppet"
    "py": "Python"
    "python": "Python"
    "q": "Q"
    "r": "R"
    "rib": "RenderMan RIB"
    "rsl": "RenderMan RSL"
    "rst": "reStructuredText"
    "ruby": "Ruby"
    "ruleslanguage": "Oracle Rules Language"
    "rust": "Rust"
    "salt": "Salt"
    "sass": "SASS"
    "scala": "Scala"
    "scheme": "Scheme"
    "scilab": "Scilab"
    "scss": "SCSS"
    "sls": "Salt"
    "smalltalk": "Smalltalk"
    "sql": "SQL"
    "swift": "Swift"
    "tcl": "Tcl"
    "tex": "TeX"
    "thrift": "Thrift"
    "typescript": "TypeScript"
    "vagrant": "Vagrant"
    "vagrantfile": "vagrant"
    "vala": "Vala"
    "vbnet": "VB.NET"
    "vbs": "VBScript"
    "vbscript": "VBScript"
    "vhdl": "VHDL"
    "vim": "VimL"
    "x86asm": "Intel x86 Assembly"
    "xhtml": "HTML"
    "xml": "XML"
