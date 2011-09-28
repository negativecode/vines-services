class FilesPage
  FILES  = 'http://getvines.com/protocol/files'
  LABELS = 'http://getvines.com/protocol/files/labels'

  constructor: (@session) ->
    @api = new Api @session
    @uploads = new Uploads
      session: @session
      jid: @api.jid
      size: this.size
      complete: (file) =>
        this.fileNode(file)
        this.findFiles name: file.name

  findLabels: ->
    $('#labels').empty()
    @api.get LABELS, {}, (result) =>
      this.labelNodeList row for row in result.rows

  labelNodeList: (label)->
    text = if label.size == 1 then 'file' else 'files'
    node = $("""
      <li data-name="" style='display:none;'>
        <span class="text"></span>
        <span class="count">#{label.size} #{text}</span>
      </li>
    """).appendTo '#labels'
    $('.text', node).text label.name
    node.attr 'data-name', label.name
    node.click (event) => this.selectLabel(event)
    node.fadeIn(100)

  selectLabel: (event) ->
    name = $(event.currentTarget).attr 'data-name'
    $('#labels li').removeClass 'selected'
    $(event.currentTarget).addClass 'selected'
    $('#files').empty()
    this.findFiles label: $(event.currentTarget).attr('data-name')

  findFiles: (criteria) ->
    @api.get FILES, criteria, (result) =>
      this.fileNode row for row in result.rows

  fileNode: (file) ->
    size = this.size file.size
    if !file.created_at
      file.created_at = Date()
    time = this.date file.created_at
    node = $("""
      <li data-id="#{file.id}" data-name="" data-size="#{size}" data-created="#{time}">
        <div class="file-icon">
          <span class="size">#{size}</span>
        </div>
        <h2></h2>
        <footer>
          <span class="time">#{time}</span>
          <ul class="labels"></ul>
          <form class="add-label">
            <div class="add-label-button"></div>
            <input type="text" placeholder="Label" style="display:none;"/>
          </form>
        </footer>
        <form class="file-form">
          <fieldset>
            <input class="cancel" type="submit" value="Delete"/>
          </fieldset>
        </form>
      </li>
    """).appendTo '#files'

    node.data 'file', file
    $('h2', node).text file.name
    node.attr 'data-name', file.name

    new Button $('.file-icon', node).get(0), ICONS.page2,
      scale: 1.0
      translation: '-2 0'
      'stroke-width': 0.1
      opacity: 1.0

    new Button $('.add-label-button', node).get(0), ICONS.plus,
      translation: '-10 -10'
      scale: 0.5

    $('form.file-form', node).submit => this.deleteFile node
    $('form.add-label', node).submit => this.addLabel node
    $('.add-label-button', node).click ->
      $('form.add-label input[type="text"]', node).show()

    this.labelNode node, label for label in file.labels

  labelNode: (node, label) ->
    labels = $('.labels', node)
    item = $("""
      <li data-name="">
        <span class="text"></span>
        <div class="remove"></div>
      </li>
    """).appendTo labels
    $('.text', item).text label
    item.attr 'data-name', label

    new Button $('.remove', item).get(0), ICONS.cross,
      translation: '-8 -8'
      scale: 0.5

    $('.remove', item).click =>
      this.removeLabel node, item

  addLabel: (node) ->
    input = $('form.add-label input[type="text"]', node)
    input.hide()
    labels = (val for val in input.val().split(/,/) when val)
    input.val ''
    file = node.data 'file'
    file.labels.push label for label in labels
    @api.save FILES, file, (result) ->
    this.labelNode node, label for label in labels
    this.findLabels()
    false

  removeLabel: (node, item) ->
    file = node.data 'file'
    remove = item.attr 'data-name'
    file.labels = (label for label in file.labels when label != remove)
    @api.save FILES, file, (result) ->
    item.fadeOut 200, -> item.remove()
    this.findLabels()

  deleteFile: (node) ->
    @api.remove FILES, node.attr('data-id'), (result) =>
      node.fadeOut 200, -> node.remove()
    false

  date: (date) ->
    date = new Date date
    day = 'Sun Mon Tue Wed Thu Fri Sat'.split(' ')[date.getDay()]
    month = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split(' ')[date.getMonth()]
    "#{day}, #{date.getDate()} #{month}, #{date.getFullYear()} @ #{date.getHours()}:#{date.getMinutes()}"

  size: (bytes) ->
    kb = bytes / 1024
    mb = kb / 1024
    gb = mb / 1024
    fmt = (num) ->
      if num >= 100
        Math.round num
      else
        num.toFixed(1).replace '.0', ''

    if kb < 1
      "#{bytes} b"
    else if mb < 1
      "#{fmt kb} k"
    else if gb < 1
      "#{fmt mb} m"
    else
      "#{fmt gb} g"

  draw: ->
    unless @session.connected()
      window.location.hash = ''
      return

    $('body').attr 'id', 'files-page'
    $('#container').hide().empty()
    $("""
      <div id="alpha" class="sidebar column y-fill">
        <h2>Labels</h2>
        <ul id="labels" class="selectable scroll y-fill"></ul>
        <div id="alpha-controls" class="controls"></div>
      </div>
      <div id="beta" class="primary column x-fill y-fill">
        <h2 id="files-title">Files <div id="search-files-icon"></div></h2>
        <div id="search-files-form"></div>
        <ul id="files" class="scroll y-fill"></ul>
      </div>
      <div id="charlie" class="sidebar column y-fill">
        <h2>Uploads</h2>
        <div id="upload-dnd" class="float">Drag files here to upload.</div>
        <ul id="uploads" class="scroll y-fill"></ul>
        <div id="charlie-controls" class="controls">
          <form id="file-form">
            <input id="open-file-chooser" type="submit" value="Select files to upload"/>
            <input id="file-chooser" type="file" multiple="true" />
          </form>
        </div>
      </div>
    """).appendTo '#container'

    $('#file-chooser').change (event) =>
      @uploads.queue event.target.files
      $('#file-chooser').val ''

    $('#file-form').submit ->
      $('#file-chooser').click()
      false

    $('#upload-dnd').bind 'dragenter', (event) ->
      event.stopPropagation()
      event.preventDefault()
      $('#upload-dnd').css 'color', '#444'

    $('#upload-dnd').bind 'dragleave', (event) ->
      $('#upload-dnd').css 'color', '#ababab'

    $('#upload-dnd').bind 'dragover', (event) ->
      event.stopPropagation()
      event.preventDefault()

    $('#upload-dnd').bind 'drop', (event) =>
      event.stopPropagation()
      event.preventDefault()
      $('#upload-dnd').css 'color', '#ababab'
      @uploads.queue event.originalEvent.dataTransfer.files

    this.findLabels()
    this.findFiles()

    $('#container').show()
    layout = this.resize()

    fn = ->
      layout.resize()
      layout.resize() # not sure why two are needed

    new Filter
      list: '#files'
      icon: '#search-files-icon'
      form: '#search-files-form'
      attrs: ['data-name', 'data-created']
      open:  fn
      close: fn

  resize: ->
    a   = $ '#alpha'
    b   = $ '#beta'
    c   = $ '#charlie'
    up  = $ '#uploads'
    dnd = $ '#upload-dnd'
    new Layout ->
      c.css 'left', a.width() + b.width()
      dnd.height up.height()
      dnd.css 'line-height', up.height() + 'px'

  class Uploads
    constructor: (options) ->
      @session = options.session
      @serviceJid = options.jid
      @size = options.size
      @complete = options.complete
      @uploads = []
      @sending = null

    queue: (files) ->
      this.add file for file in files when not this.find file
      this.process()

    add: (file) ->
      node  = this.node file
      meter = $ '.meter', node
      @uploads.push new Transfer
        to: @serviceJid()
        file: file
        session: @session
        progress: (pct) ->
          meter.css 'width', pct + '%'
        complete: =>
          this.remove file
          this.complete file if this.complete
          @sending = null if file.name == @sending.name
          this.process()

    process: ->
      return if @sending
      if upload = @uploads[0]
        @sending = upload.file
        upload.start()
      else
        @sending = null
        this.fileNode(upload.file)

    find: (file) ->
      (up for up in @uploads when up.file.name == file.name).shift()

    remove: (file) ->
      @uploads = (up for up in @uploads when up.file.name != file.name)
      node = $ "#uploads li[data-file='#{file.name}']"
      node.fadeOut 200, -> node.remove()

    node: (file) ->
      node = $("""
        <li data-file="" style="display:none;">
          <form class="inset">
            <h2></h2>
            <div class="progress">
              <div class="meter"></div>
              <span class="text">#{this.size file.size}</span>
              <div class="cancel"></div>
            </div>
          </form>
        </li>
      """).appendTo '#uploads'
      node.fadeIn 200
      $('h2', node).text file.name
      node.attr 'data-file', file.name

      new Button $('.cancel', node).get(0), ICONS.cross,
        translation: '-8 -8'
        scale: 0.5
      $('.cancel', node).click => this.cancel file
      node

    cancel: (file) ->
      upload.stop() if upload = this.find file
