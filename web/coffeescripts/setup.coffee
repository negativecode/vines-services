class SetupPage
  SERVICES = 'http://getvines.com/protocol/services'
  SYSTEMS  = 'http://getvines.com/protocol/systems'
  USERS    = 'http://getvines.com/protocol/users'

  constructor: (@session) ->
    @api = new Api @session
    @layout = null
    @selected = null
    @services = []
    @users = []

  findSystem: (name) ->
    @api.get SYSTEMS, {name: name}, (result) =>
      this.drawSystemInfo(result)

  findServices: ->
    @api.get SERVICES, {}, (result) =>
      @services = result.rows
      this.drawServices()

  drawServices: ->
    return if $('#setup-page #services').length == 0
    $('#services').empty()
    for service in @services
      node = $("""
        <li>
          <input id='service-#{service.id}' type='checkbox' value='#{service.id}'/>
          <label for='service-#{service.id}'></label>
        </li>
      """).appendTo '#services'
      $('label', node).text service.name
    $('#services input[type="checkbox"]').val @selected.services if @selected
    if @selected && !@api.user.permissions.services
      $('#services input[type="checkbox"]').prop 'disabled', true

  findUsers: ->
    @api.get USERS, {}, (result) =>
      @users = result.rows
      this.drawUsers()

  drawUsers: ->
    return if $('#setup-page #users').length == 0
    $('#users').empty()
    systems = $('#systems-nav').hasClass 'selected'
    for user in @users
      this.userNode(user) if user.system == systems

  userNode: (user) ->
    node = $("""
      <li data-name="" data-jid="#{user.jid}" id="#{user.jid}">
        <span class="text"></span>
        <span class="jid">#{user.jid}</span>
      </li>
    """).appendTo '#users'

    name = this.userName(user)
    $('.text', node).text name
    node.attr 'data-name', name
    node.click (event) => this.selectUser event.currentTarget
    node

  userName: (user) ->
    user.name || user.jid.split('@')[0]

  selectUser: (node) ->
    jid = $(node).attr 'data-jid'
    name = $(node).attr 'data-name'

    $('#users li').removeClass 'selected'
    $(node).addClass 'selected'

    $('#remove-user-msg').html "Are you sure you want to remove " +
      "<strong>#{name}</strong>?"
    $('#remove-user-form .buttons').fadeIn 200
    @api.get USERS, jid: jid, (result) =>
      @selected = result
      if result.system
        this.drawSystemEditor result
      else
        this.drawUserEditor result

  removeUser: ->
    this.toggleForm '#remove-user-form'
    selected = $("#users li[data-jid='#{@selected.jid}']")
    @api.remove USERS, @selected.jid, (result) =>
      selected.fadeOut 200, =>
        @users = (u for u in @users when u.jid != @selected.jid)
        selected.remove()
        @selected = null
        if $('#users-nav').hasClass 'selected'
          this.drawUserBlankSlate()
        else
          this.drawSystemBlankSlate()

  selectTask: (event) ->
    @selected = null
    $('#setup li').removeClass 'selected secondary'
    $(event.currentTarget).addClass 'selected secondary'
    $('form.overlay').fadeOut 100, => @layout.resize()
    switch $(event.currentTarget).attr('id')
      when 'users-nav'
        $('#beta-header').text 'Users'
        $('#remove-user-form h2').text 'Remove User'
        $('#remove-user-msg').html "Select a user to delete."
        $('#remove-user-form .buttons').hide()
        this.drawUsers()
        this.drawUserBlankSlate()
        this.toggleBetaControls @api.user.permissions.users
      when 'systems-nav'
        $('#beta-header').text 'Systems'
        $('#remove-user-form h2').text 'Remove System'
        $('#remove-user-msg').html "Select a system to delete."
        $('#remove-user-form .buttons').hide()
        this.drawUsers()
        this.drawSystemBlankSlate()
        this.toggleBetaControls @api.user.permissions.systems

  toggleBetaControls: (show) ->
    if show
      $('#beta-controls div').show()
    else
      $('#beta-controls div').hide()

  toggleForm: (form, fn) ->
    form = $(form)
    $('form.overlay').each ->
      $(this).hide() unless this.id == form.attr 'id'
    if form.is ':hidden'
      fn() if fn
      form.fadeIn 100
    else
      form.fadeOut 100, =>
        form[0].reset()
        @layout.resize()
        fn() if fn

  validateUser: ->
    $('#user-name-error').empty()
    $('#password-error').empty()
    valid = true

    password1 = $('#password1').val().trim()
    password2 = $('#password2').val().trim()

    if @selected # existing user
      if password2.length > 0 && password2.length < 8
        $('#password-error').text 'Password must be at least 8 characters.'
        valid = false

      # admin updating a user's password
      if @session.bareJid() != @selected.jid
        if password1 != password2
          $('#password-error').text 'Passwords must match.'
          valid = false

    else # new user
      node = $('#user-name').val().trim()
      if node == ''
        $('#user-name-error').text 'User name is required.'
        valid = false

      if node.match /[\s"&'\/:<>@]/
        $('#user-name-error').text 'User name contains forbidden characters.'
        valid = false

      if password1.length == 0 || password2.length == 0
        $('#password-error').text 'Password is required.'
        valid = false

      if password1 != password2
        $('#password-error').text 'Passwords must match.'
        valid = false

      if password2.length < 8
        $('#password-error').text 'Password must be at least 8 characters.'
        valid = false

    valid

  saveUser: ->
    return false unless this.validateUser()
    user =
      jid: $('#jid').val()
      username: $('#user-name').val()
      name: $('#name').val()
      password1: $('#password1').val()
      password2: $('#password2').val()
      services: $('#services :checked').map(-> $(this).val()).get()
      permissions:
        systems:  $('#perm-systems').prop('checked')
        services: $('#perm-services').prop('checked')
        files:    $('#perm-files').prop('checked')
        users:    $('#perm-users').prop('checked')

    @api.save USERS, user, (result) =>
      new Notification 'User saved successfully'
      $('#jid').val result.jid
      node = $("#users li[data-jid='#{result.jid}']")
      if node.length == 0
        @users.push result
        node = this.userNode result
        this.selectUser node
      else
        selected = (u for u in @users when u.jid == result.jid)[0]
        selected.name = this.userName result
        $('.text', node).text this.userName result
    false

  validateSystem: ->
    $('#user-name-error').empty()
    valid = true
    node = $('#user-name').val().trim()
    unless @selected # new user
      if node == ''
        $('#user-name-error').text 'Hostname is required.'
        valid = false

      if node.match /[\s"&'\/:<>@]/
        $('#user-name-error').text 'Hostname contains forbidden characters.'
        valid = false
    valid

  saveSystem: ->
    return false unless this.validateSystem()
    user =
      jid: $('#jid').val()
      username: $('#user-name').val()
      password1: $('#password1').val()
      password2: $('#password1').val()
      system: true

    @api.save USERS, user, (result) =>
      new Notification 'System saved successfully'
      $('#jid').val result.jid
      node = $("#users li[data-jid='#{result.jid}']")
      if node.length == 0
        @users.push result
        node = this.userNode result
        this.selectUser node
      else
        @selected.name = result.name
        $('.text', node).text result.name
    false

  rand: ->
    Math.floor(Math.random() * 16)

  token: ->
    (this.rand().toString(16) for i in [0..127]).join('')

  drawUserBlankSlate: ->
    $('#charlie').empty()
    msg = if @api.user.permissions.users
      'Select a user account to update or add a new user.'
    else
      'Select a user account to update.'

    $("""
      <form id="blank-slate">
        <p>#{msg}</p>
        <input type="submit" id="blank-slate-add" value="Add User"/>
      </form>
    """).appendTo '#charlie'
    $('#blank-slate-add').remove() unless @api.user.permissions.users
    $('#blank-slate').submit =>
      this.drawUserEditor()
      false

  drawSystemBlankSlate: ->
    $('#charlie').empty()
    $("""
      <form id="blank-slate">
        <p>
          Systems need a user account before they can connect and
          authenticate with the chat server.
        </p>
        <input type="submit" id="blank-slate-add" value="Add System"/>
      </form>
    """).appendTo '#charlie'
    $('#blank-slate-add').remove() unless @api.user.permissions.systems
    $('#blank-slate').submit =>
      this.drawSystemEditor()
      false

  draw: ->
    unless @session.connected()
      window.location.hash = ''
      return

    $('body').attr 'id', 'setup-page'
    $('#container').hide().empty()
    $("""
      <div id="alpha" class="sidebar column y-fill">
        <h2>Setup</h2>
        <ul id="setup" class="selectable scroll y-fill">
          <li id="users-nav" class='selected secondary'>
            <span class="text">Users</span>
          </li>
          <li id="systems-nav">
            <span class="text">Systems</span>
          </li>
        </ul>
        <div id="alpha-controls" class="controls"></div>
      </div>
      <div id="beta" class="sidebar column y-fill">
        <h2><span id="beta-header">Users</span> <div id="search-users-icon"></div></h2>
        <div id="search-users-form"></div>
        <ul id="users" class="selectable scroll y-fill"></ul>
        <form id="remove-user-form" class="overlay" style="display:none;">
          <h2>Remove User</h2>
          <p id="remove-user-msg">Select a user to delete.</p>
          <fieldset class="buttons" style="display:none;">
            <input id="remove-user-cancel" type="button" value="Cancel"/>
            <input id="remove-user-ok" type="submit" value="Remove"/>
          </fieldset>
        </form>
        <div id="beta-controls" class="controls">
          <div id="add-user"></div>
          <div id="remove-user"></div>
        </div>
      </div>
      <div id="charlie" class="primary column x-fill y-fill"></div>
    """).appendTo '#container'

    this.drawUserBlankSlate()

    $('#setup li').click (event) => this.selectTask event

    this.findUsers()
    this.findServices()

    $('#container').show()
    @layout = this.resize()

    new Button '#add-user',    ICONS.plus
    new Button '#remove-user', ICONS.minus

    $('#beta-controls div').hide() unless @api.user.permissions.users
    $('#systems-nav').hide() unless @api.user.permissions.systems

    $('#add-user').click =>
      if $('#users-nav').hasClass 'selected'
        this.drawUserEditor()
      else
        this.drawSystemEditor()

    $('#remove-user').click        => this.toggleForm '#remove-user-form'
    $('#remove-user-cancel').click => this.toggleForm '#remove-user-form'
    $('#remove-user-form').submit  =>
      this.removeUser()
      false

    fn = =>
      @layout.resize()
      @layout.resize() # not sure why two are needed

    new Filter
      list: '#users'
      icon: '#search-users-icon'
      form: '#search-users-form'
      attrs: ['data-jid', 'data-name']
      open:  fn
      close: fn

  drawUserEditor: (user) ->
    unless user
      @selected = null
      $('#users li').removeClass 'selected'

    $('#charlie').empty()
    $("""
      <form id="editor-form" class="sections y-fill scroll">
        <div>
          <section>
            <h2>User</h2>
            <fieldset id="jid-fields">
              <input id="jid" type="hidden" value=""/>
              <label for="name">Real Name</label>
              <input id="name" type="text" maxlength="1024"/>
            </fieldset>
          </section>
          <section>
            <h2>Password</h2>
            <fieldset>
              <label id="password1-label" for="password1">Current Password</label>
              <input id="password1" type="password" maxlength="1024"/>
              <label id="password2-label" for="password2">New Password</label>
              <input id="password2" type="password" maxlength="1024"/>
              <p id="password-error" class="error"></p>
            </fieldset>
          </section>
          <section>
            <h2>Permissions</h2>
            <fieldset>
              <label>Manage</label>
              <ul id="permissions">
                <li>
                  <input id="perm-systems" type="checkbox" value="systems"/>
                  <label for="perm-systems">Systems</label>
                </li>
                <li>
                  <input id="perm-services" type="checkbox" value="services"/>
                  <label for="perm-services">Services</label>
                </li>
                <li>
                  <input id="perm-users" type="checkbox" value="users"/>
                  <label for="perm-users">Users</label>
                </li>
                <li>
                  <input id="perm-files" type="checkbox" value="files"/>
                  <label for="perm-files">Files</label>
                </li>
              </ul>
            </fieldset>
          </section>
          <section>
            <h2>Services</h2>
            <fieldset>
              <label>Access To</label>
              <ul id="services" class="scroll"></ul>
            </fieldset>
          </section>
        </div>
      </form>
      <form id="editor-buttons">
        <input id="save" type="submit" value="Save"/>
      </form>
    """).appendTo '#charlie'

    if user
      $("""
        <label>Account Name</label>
        <p>#{user.jid}</p>
      """).prependTo '#jid-fields'

      $('#name').focus()
      if @session.bareJid() != user.jid
        $('#password1-label').text 'Password'
        $('#password2-label').text 'Password Again'
      $('#jid').val user.jid
      $('#name').val user.name
      $('#user-name').val user.jid.split('@')[0]
      for name in 'services systems files users'.split(' ')
        $("#perm-#{name}").prop('checked', true) if user.permissions[name]
        $("#perm-#{name}").prop('disabled', true) if @session.bareJid() == user.jid
    else
      $("""
        <label for="user-name">User Name</label>
        <input id="user-name" type="text" maxlength="1023"/>
        <p id="user-name-error" class="error"></p>
      """).prependTo '#jid-fields'
      $('#password1-label').text 'Password'
      $('#password2-label').text 'Password Again'
      $('#user-name').focus()

    this.drawServices() if @services.length > 0

    @layout.resize()
    $('#editor-form').submit    => this.saveUser()
    $('#editor-buttons').submit => this.saveUser()

  drawSystemEditor: (user) ->
    unless user
      @selected = null
      $('#users li').removeClass 'selected'

    $('#charlie').empty()
    $("""
      <form id="editor-form" class="sections y-fill scroll">
        <div>
          <section>
            <h2>System</h2>
            <fieldset id="jid-fields">
              <input id="jid" type="hidden" value=""/>
              <label id="password1-label" for="password1">Authentication Token</label>
              <div id="token-container">
                <input id="password1" type="text" readonly placeholder="Press Generate to create a new token"/>
                <input id="new-token" type="button" value="Generate"/>
              </div>
            </fieldset>
          </section>
          <section id="info">
            <h2>Info</h2>
            <fieldset>
              <label>Platform</label>
              <p id="info-platform">-</p>
              <label>Hostname</label>
              <p id="info-fqdn">-</p>
              <label>IP Address</label>
              <p id="info-ip">-</p>
              <label>MAC Address</label>
              <p id="info-mac">-</p>
            </fieldset>
          </section>
        </div>
      </form>
      <form id="editor-buttons">
        <input id="save" type="submit" value="Save"/>
      </form>
    """).appendTo '#charlie'

    $('#new-token').click => $('#password1').val this.token()

    this.findSystem(user.jid.split('@')[0]) if user

    if user
      $("""
        <label>Account Name</label>
        <p>#{user.jid}</p>
      """).prependTo '#jid-fields'
      $('#jid').val user.jid
      $('#user-name').val user.jid.split('@')[0]
    else
      $("""
        <label for="user-name">Hostname</label>
        <input id="user-name" type="text" maxlength="1023"/>
        <p id="user-name-error" class="error"></p>
      """).prependTo '#jid-fields'
      $('#user-name').focus()
      $('#password1').val this.token()

    @layout.resize()
    $('#editor-form').submit    => this.saveSystem()
    $('#editor-buttons').submit => this.saveSystem()

  drawSystemInfo: (system) ->
    $('#info-platform').text system.platform
    $('#info-fqdn').text system.fqdn
    $('#info-ip').text system.ipaddress
    $('#info-mac').text system.macaddress

  resize: ->
    a = $ '#alpha'
    b = $ '#beta'
    c = $ '#charlie'
    new Layout ->
      c.css 'left', a.outerWidth() + b.outerWidth()
