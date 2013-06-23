class @SystemsPage
  constructor: (@session) ->
    @session.onRoster   ( ) => this.roster()
    @session.onMessage  (m) => this.message(m)
    @session.onPresence (p) => this.presence(p)
    @commands = new Commands
    @chats = {}
    @currentContact = null
    @layout = null

  datef: (millis) ->
    d = new Date(millis)
    meridian = if d.getHours() >= 12 then ' pm' else ' am'
    hour = if d.getHours() > 12 then d.getHours() - 12 else d.getHours()
    hour = 12 if hour == 0
    minutes = d.getMinutes() + ''
    minutes = '0' + minutes if minutes.length == 1
    hour + ':' + minutes + meridian

  groupContacts: ->
    groups = {}
    for jid, contact of @session.roster
      for group in contact.groups
        (groups[group] ||= []).push contact
    groups

  roster: ->
    groups = this.groupContacts()
    sorted = (group for group, contacts of groups)
    sorted = sorted.sort (a, b) ->
      a = a.toLowerCase()
      b = b.toLowerCase()
      if a > b then 1 else if a < b then -1 else 0

    items = $('#roster-items').empty()
    for group in sorted
      contacts = groups[group]
      optgroup = $('<li class="group"></li>').appendTo items
      optgroup.text group
      optgroup.attr 'data-group', group
      for contact in contacts
        option = $("""
          <li data-jid="#{contact.jid}">
            <span class="icon"></span>
            <span class="text"></span>
            <span class="unread" style="display:none;"></span>
          </li>
        """).appendTo items
        option.addClass 'offline' if contact.offline()
        option.click (event) => this.selectContact event
        name = contact.name || contact.jid.split('@')[0]
        option.attr 'data-name', name
        option.attr 'data-group', group
        $('.text', option).text name
        opts =
          fill: '#fff'
          stroke: '#404040'
          'stroke-width': 0.3
          opacity: 1.0
          scale: 0.65
        icon = switch group
          when 'People'   then ICONS.man
          when 'Services' then ICONS.magic
          else ICONS.run
        new Button $('.icon', option), icon, opts

  message: (message) ->
    this.queueMessage message
    me   = message.from == @session.jid()
    from = message.from.split('/')[0]

    if me || from == @currentContact
      bottom = this.atBottom()
      this.appendMessage message
      this.scroll({animate: true}) if bottom || me
    else
      chat = this.chat message.from
      chat.unread++
      this.eachContact from, (node) ->
        $('.unread', node).text(chat.unread).show()

  eachContact: (jid, callback) ->
    for node in $("#roster-items li[data-jid='#{jid}']").get()
      callback $(node)

  appendMessage: (message) ->
    me      = message.from == @session.jid()
    proxied = $('jid', message.node).text()
    from    = (proxied || message.from).split('/')[0]
    contact = @session.roster[from]
    name    = if contact then (contact.name || from) else from
    node    = $("""<li data-jid="#{from}"><pre></pre></li>""").appendTo '#messages'
    prefix  = if me then '$ ' else ''
    $('pre', node).text prefix + message.text
    $('#message-form').css 'top', '0px'
    unless me
      node.append("""
        <footer>
          <span class="author"></span> @
          <span class="time">#{this.datef message.received}</span>
        </footer>
      """)
      $('.author', node).text name

  queueMessage: (message) ->
    me   = message.from == @session.jid()
    full = message[if me then 'to' else 'from']
    chat = this.chat full
    chat.jid = full
    chat.messages.push message

  chat: (jid) ->
    bare = jid.split('/')[0]
    chat = @chats[bare]
    unless chat
      chat = jid: jid, messages: [], unread: 0
      @chats[bare] = chat
    chat

  presence: (presence) ->
    from = presence.from.split('/')[0]
    return if from == @session.bareJid()
    if !presence.type || presence.offline
      contact = @session.roster[from]
      this.eachContact from, (node) ->
        if contact.offline()
          node.addClass 'offline'
        else
          node.removeClass 'offline'

    if presence.offline
      this.chat(from).jid = from

  selectContact: (event) ->
    $('#blank-slate').fadeOut(200, -> $(this).remove())
    $('#roster').hide()
    $('#message').focus()

    selected = $(event.currentTarget)
    jid = selected.attr 'data-jid'
    contact = @session.roster[jid]
    return if @currentContact == jid
    @currentContact = jid

    $('#message-label').text $('.text', selected).text()
    $('#messages').empty()
    $('#message-form').css 'top', '10px'
    @layout.resize()
    this.restoreChat(jid)

  restoreChat: (jid) ->
    chat = @chats[jid]
    messages = []
    if chat
      messages = chat.messages
      chat.unread = 0
      this.eachContact jid, (node) ->
        $('.unread', node).text('').hide()
    this.appendMessage msg for msg in messages
    this.scroll()

  scroll: (opts) ->
    opts ||= {}
    msgs = $ '#messages'
    if opts.animate
      msgs.animate(scrollTop: msgs.prop('scrollHeight'), 400)
    else
      msgs.scrollTop msgs.prop('scrollHeight')

  atBottom: ->
    msgs = $('#messages')
    bottom = msgs.prop('scrollHeight') - msgs.outerHeight()
    msgs.scrollTop() >= bottom

  send: ->
    return false unless @currentContact
    input = $('#message')
    text = input.val().trim()
    if text
      chat = @chats[@currentContact]
      jid = if chat then chat.jid else @currentContact
      this.message
        from: @session.jid()
        text: text
        to: jid
        received: new Date()
      @session.sendMessage jid, text
      @commands.push text
    input.val ''
    false

  showRoster: ->
    container = $ '#container'
    form      = $ '#message-form'
    roster    = $ '#roster'
    items     = $ '#roster-items'
    rform     = $ '#roster-form'

    up = container.height() - form.position().top < container.height() / 2
    if up
      roster.css 'top', ''
      roster.css 'bottom', (form.outerHeight() + 5) + 'px'
      height = container.height() - form.outerHeight() - 20
    else
      roster.css 'bottom', ''
      roster.css 'top', (form.position().top + form.outerHeight()) + 'px'
      height = container.height() - form.position().top - 30

    items.css 'max-height', (height - rform.outerHeight() - 40)  + 'px'
    roster.css 'max-height', height + 'px'
    roster.show()

  drawBlankSlate: ->
    $("""
      <form id="blank-slate" class="float">
        <p>
          Services, and individual systems, can be controlled by sending
          them shell commands through this terminal. Select a system to chat with
          to get started.
        </p>
        <input type="submit" value="Select System"/>
      </form>
    """).appendTo '#alpha'
    $('#blank-slate').submit =>
      this.showRoster()
      @layout.resize()
      false

  draw: ->
    unless @session.connected()
      window.location.hash = ''
      return

    $('body').attr 'id', 'systems-page'
    $('#container').hide().empty()
    $("""
      <div id="alpha" class="primary column x-fill y-fill">
        <ul id="messages" class="scroll"></ul>
        <form id="message-form">
          <label id="message-label"></label>
          <input id="message" name="message" type="text" maxlength="1024" placeholder="Type a command and press enter to send"/>
        </form>
        <div id="roster" class="float" style="display:none;">
          <ul id="roster-items"></ul>
          <div id="roster-form"></div>
        </div>
      </div>
    """).appendTo '#container'
    # padding is removed when first message is received
    $('#message-form').css 'top', '10px'
    $('#message-form').submit => this.send()
    $('#messages').click -> $('#roster').hide()
    $('#message').focus  -> $('#roster').hide()
    $(document).keyup (e) ->
      $('#roster').hide() if e.keyCode == 27 # escape

    this.roster()
    $('#message-label').click =>
      roster = $('#roster')
      if roster.is(':visible')
        roster.hide()
      else
        this.showRoster()

    $('#message').keyup (e) =>
      switch e.keyCode # up, down keys trigger history
        when 38 then $('#message').val @commands.prev()
        when 40 then $('#message').val @commands.next()

    if @currentContact
      this.restoreChat(@currentContact) if @currentContact
      contact = @session.roster[@currentContact]
      name = contact.name || contact.jid.split('@')[0]
      $('#message-label').text name
      $('#message').focus()
    else
      this.drawBlankSlate()

    $('#container').show()
    @layout = this.resize()
    this.scroll()
    $('#message').focus()

    new Filter
      list: '#roster-items'
      form: '#roster-form'
      attrs: ['data-jid', 'data-name']
    $('form', '#roster-form').show()

  resize: ->
    container = $ '#container'
    msgs      = $ '#messages'
    msg       = $ '#message'
    form      = $ '#message-form'
    label     = $ '#message-label'
    new Layout ->
      msg.width form.width() - label.width() - 32
      msgs.css 'max-height', container.height() - form.height()
