{Disposable} = require 'atom'
path = require 'path'

class StatusBarTileView extends HTMLElement
  prepend: 'WakaTime '

  init: ->
    @classList.add('wakatime-status-bar-tile', 'inline-block')

    @icon = document.createElement('img')
    @icon.classList.add('inline-block')
    @icon.setAttribute('src', __dirname + path.sep + 'icon.png')
    @icon.style.width = '1.4555em'
    @icon.style.height = '1.4555em'
    @icon.style.verticalAlign = 'middle'
    @icon.style.marginRight = '0.3em'
    @appendChild @icon

    @msg = document.createElement('a')
    @msg.classList.add('inline-block')
    @msg.href = 'https://wakatime.com/dashboard'
    @appendChild @msg

    @setStatus "initializing..."

  setStatus: (content) ->
    @msg?.textContent = @prepend + content

  setTitle: (text) ->
    @tooltip?.dispose()
    @tooltip = atom.tooltips.add this,
      title: text

module.exports = document.registerElement('wakatime-status-bar-tile', prototype: StatusBarTileView.prototype, extends: 'div')
