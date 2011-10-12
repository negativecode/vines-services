class SystemsPage
  constructor: (@session) ->
    @session.onRoster   ( ) => this.roster()
    @session.onCard     (c) => this.card(c)
    @session.onMessage  (m) => this.message(m)
    @session.onPresence (p) => this.presence(p)
    @commands = new Commands
    @chats = {}
    @currentContact = null

  datef: (millis) ->
    d = new Date(millis)
    meridian = if d.getHours() >= 12 then ' pm' else ' am'
    hour = if d.getHours() > 12 then d.getHours() - 12 else d.getHours()
    hour = 12 if hour == 0
    minutes = d.getMinutes() + ''
    minutes = '0' + minutes if minutes.length == 1
    hour + ':' + minutes + meridian

  card: (card) ->
    this.eachContact card.jid, (node) =>
      $('.vcard-img', node).attr 'src', @session.avatar card.jid

  roster: ->
    roster = $('#roster')

    $('li', roster).each (ix, node) =>
      jid = $(node).attr('data-jid')
      $(node).remove() unless @session.roster[jid]

    setName = (node, contact) ->
      $('.text', node).text contact.name || contact.jid
      node.attr 'data-name', contact.name || ''
      node.attr 'data-groups', contact.groups || ''

    for jid, contact of @session.roster
      found = $("#roster li[data-jid='#{jid}']")
      setName(found, contact)
      if found.length == 0
        if contact.groups[0] == "Vines"
          img_src = "images/default-service.png"
        else
          img_src = "#{@session.avatar jid}"
        node = $("""
          <li data-jid="#{jid}" data-name="" data-group="" class="offline">
            <span class="text"></span>
            <span class="status-msg">Offline</span>
            <span class="unread" style="display:none;"></span>
            <img class="vcard-img" id="#{jid}-avatar" alt="#{jid}" src="#{img_src}"/>
          </li>
        """).appendTo roster
        setName(node, contact)
        node.click (event) => this.selectContact(event)

  message: (message) ->
    this.queueMessage message
    me   = message.from == @session.jid()
    from = message.from.split('/')[0]

    if me || from == @currentContact
      bottom = this.atBottom()
      this.appendMessage message
      this.scroll() if bottom
    else
      chat = this.chat message.from
      chat.unread++
      this.eachContact from, (node) ->
        $('.unread', node).text(chat.unread).show()

  eachContact: (jid, callback) ->
    for node in $("#roster li[data-jid='#{jid}']").get()
      callback $(node)

  appendMessage: (message) ->
    me      = message.from == @session.jid()
    from    = message.from.split('/')[0]
    contact = @session.roster[from]
    name    = if contact then (contact.name || from) else from
    node    = $("""<li data-jid="#{from}"><pre></pre></li>""").appendTo '#messages'
    prefix  = if me then '$ ' else ''
    $('pre', node).text prefix + message.text
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
        $('.status-msg', node).text contact.status()
        if contact.offline()
          node.addClass 'offline'
        else
          node.removeClass 'offline'

    if presence.offline
      this.chat(from).jid = from

  selectContact: (event) ->
    jid = $(event.currentTarget).attr 'data-jid'
    contact = @session.roster[jid]
    return if @currentContact == jid
    @currentContact = jid

    $('#roster li').removeClass 'selected'
    $(event.currentTarget).addClass 'selected'
    $('#chat-title').text('Chat with ' + (contact.name || contact.jid))
    $('#messages').empty()

    chat = @chats[jid]
    messages = []
    if chat
      messages = chat.messages
      chat.unread = 0
      this.eachContact jid, (node) ->
        $('.unread', node).text('').hide()

    this.appendMessage msg for msg in messages
    this.scroll()

  scroll: ->
    msgs = $ '#messages'
    msgs.animate(scrollTop: msgs.prop('scrollHeight'), 400)

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

  draw: ->
    unless @session.connected()
      window.location.hash = ''
      return

    $('body').attr 'id', 'systems-page'
    $('#container').hide().empty()
    $("""
      <div id="alpha" class="sidebar column y-fill">
        <h2>Buddies <div id="search-roster-icon"></div></h2>
        <div id="search-roster-form"></div>
        <ul id="roster" class="selectable scroll y-fill"></ul>
      </div>
      <div id="beta" class="primary column x-fill y-fill">
        <h2 id="chat-title">Select a buddy or service to start communicating</h2>
        <ul id="messages" class="scroll y-fill"></ul>
        <form id="message-form">
          <input id="message" name="message" type="text" maxlength="1024" placeholder="Type a message and press enter to send"/>
        </form>
      </div>
    """).appendTo '#container'

    this.roster()

    $('#message').focus -> $('form.overlay').fadeOut()
    $('#message').keyup (e) =>
      switch e.keyCode # up, down keys trigger history
        when 38 then $('#message').val @commands.prev()
        when 40 then $('#message').val @commands.next()

    $('#message-form').submit  => this.send()

    $('#container').show()
    layout = this.resize()

    fn = ->
      layout.resize()
      layout.resize() # not sure why two are needed

    new Filter
      list: '#roster'
      icon: '#search-roster-icon'
      form: '#search-roster-form'
      attrs: ['data-jid', 'data-name']
      open:  fn
      close: fn

  resize: ->
    msg  = $ '#message'
    form = $ '#message-form'
    new Layout ->
      msg.width form.width() - 32
