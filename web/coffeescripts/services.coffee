class ServicesPage
  SERVICES = 'http://getvines.com/protocol/services'
  MEMBERS  = 'http://getvines.com/protocol/services/members'
  SYSTEMS  = 'http://getvines.com/protocol/systems'
  ATTRS    = 'http://getvines.com/protocol/systems/attributes'
  USERS    = 'http://getvines.com/protocol/users'

  constructor: (@session) ->
    @api = new Api @session
    @selectedService = null
    @validateTimeout = null
    @layout = null
    @users = []

  deleteService: (event) ->
    this.drawBlankSlate()
    this.toggleForm '#remove-contact-form'
    selected = $("#services li[data-id='#{@selectedService.id}']")
    @api.remove SERVICES, @selectedService.id, (result) =>
      selected.fadeOut 200, ->
        selected.remove()
        @selectedService = null
    false

  icon: (member) ->
    icons =
      darwin:  'mac.png'
      linux:   'linux.png'
      windows: 'windows.png'
    icon = icons[member.os] || 'run.png'
    "images/#{icon}"

  drawMember: (member) ->
    return unless this.editorVisible()
    node = $("""
      <li>
        <span class="icon"><img src="#{this.icon(member)}"/></span>
        <span class="text"></span>
      </li>
    """).appendTo '#members'
    $('.text', node).text member.name

  operators: ->
    for operator in ['like', 'not like', 'starts with', 'ends with', 'is', 'is not', '>', '>=', '<', '<=', 'and', 'or']
      node = $("""
        <li data-selector="#{operator}">
          #{operator}
        </li>
      """).appendTo '#operators'
      node.click (event) =>
        $('#syntax').focus()
        name = $(event.currentTarget).attr 'data-selector'
        $('#syntax').val($('#syntax').val() + " #{name} ")
        this.validateIn()

  selectService: (node) ->
    id = $(node).attr 'data-id'
    name = $(node).attr 'data-name'

    $('#services li').removeClass 'selected'
    $(node).addClass 'selected'

    $('#remove-service-msg').html "Are you sure you want to remove the " +
      "<strong>#{name}</strong> service?"
    $('#remove-service-form .buttons').fadeIn 200
    @api.get SERVICES, id: id, (result) =>
      @selectedService = result
      this.drawEditor(result)

  serviceNode: (service) ->
    label = if service.size == 1 then 'system' else 'systems'
    node = $("""
      <li data-id="#{service.id}" data-name="" data-size="#{service.size}">
        <span class="text">#{service.name}</span>
        <span class="count">#{service.size} #{label}</span>
      </li>
    """).appendTo '#services'
    node.attr 'data-name', service.name
    $('.text', node).text service.name
    node.click (event) => this.selectService event.currentTarget
    node

  findServices: ->
    @api.get SERVICES, {}, (result) =>
      this.serviceNode row for row in result.rows

  findMembers: (id) ->
    @api.get MEMBERS, id: id, (result) =>
      this.drawMember row for row in result.rows

  findUsers: (syntax) ->
    @api.get USERS, {}, (result) =>
      @users = (row for row in result.rows when !row.system)
      this.drawUsers()

  attributeNode: (attribute) ->
    node = $('<li data-name=""></li>').appendTo '#attributes'
    node.text attribute
    node.attr 'data-name', attribute
    node.click (event) =>
      $('#syntax').focus()
      name = $(event.currentTarget).attr 'data-name'
      $('#syntax').val($('#syntax').val() + " #{name} ")
      this.validateIn()

  findAttributes: (syntax) ->
    @api.get ATTRS, {}, (result) =>
      this.attributeNode row for row in result.rows

  validateIn: (millis)->
    clearTimeout @validateTimeout
    @validateTimeout = setTimeout (=> this.validate()), millis || 500

  validate: ->
    $('#syntax-status').text ''

    # only validate if text changed
    prev = $('#syntax').data 'prev'
    code = $('#syntax').val().trim()
    $('#syntax').data 'prev', code
    return unless code && code != prev

    $('#syntax-status').text 'Searching . . .'
    $('#members').empty()
    @api.get2 MEMBERS, code, (result) =>
      if result.ok
        $('#syntax-status').text ''
        this.drawMember row for row in result.rows
      else
        $('#syntax-status').text result.error

  validateForm: ->
    $('#name-error').empty()
    $('#unix-users-error').empty()
    valid = true

    name = $('#name').val().trim()
    if name == ''
      $('#name-error').text 'Name is required.'
      valid = false

    if this.accounts().length == 0
      $('#unix-users-error').text 'At least one user account is required.'
      valid = false

    valid

  accounts: ->
    accounts = $('#unix-users').val().split(',')
    (u.trim() for u in accounts when u.trim().length > 0)

  save: ->
    return false unless this.validateForm()
    users = $('#users :checked').map(-> $(this).val()).get()
    service =
      name: $('#name').val()
      code: $('#syntax').val()
      accounts: this.accounts()
      users: users
    service['id'] = $('#id').val() if $('#id').val().length > 0

    @api.save SERVICES, service, (result) =>
      new Notification 'Service saved successfully'
      result.size = $('#members').length
      $('#id').val result.id
      node = $("#services li[data-id='#{result.id}']")
      if node.length == 0
        node = this.serviceNode result
        this.selectService node
      else
        $('.text', node).text result.name
    false

  drawBlankSlate: ->
    $('#beta').empty()
    $("""
      <form id="blank-slate">
        <p>
          Services are dynamically updated groups of systems based on
          criteria you define. Send a command to the service and it runs
          on every system in the group.
        </p>
        <input type="submit" id="blank-slate-add" value="Add Service"/>
      </form>
    """).appendTo '#beta'
    $('#blank-slate-add').remove() unless @api.user.permissions.services
    $('#blank-slate').submit =>
      this.drawEditor()
      false

  draw: ->
    unless @session.connected()
      window.location.hash = ''
      return

    $('body').attr 'id', 'services-page'
    $('#container').hide().empty()
    $("""
      <div id="alpha" class="sidebar column y-fill">
        <h2>Services <div id="search-services-icon"></div></h2>
        <div id="search-services-form"></div>
        <ul id="services" class="selectable scroll y-fill"></ul>
        <div id="alpha-controls" class="controls">
          <div id="add-service"></div>
          <div id="remove-service"></div>
        </div>
        <form id="remove-service-form" class="overlay" style="display:none;">
          <h2>Remove Service</h2>
          <p id="remove-service-msg">Select a service in the list above to remove.</p>
          <fieldset class="buttons" style="display:none;">
            <input id="remove-service-cancel" type="button" value="Cancel"/>
            <input id="remove-service-ok" type="submit" value="Remove"/>
          </fieldset>
        </form>
      </div>
      <div id="beta" class="primary column x-fill y-fill"></div>
      <div id="charlie" class="sidebar column y-fill">
        <h2>Operators</h2>
        <ul id="operators"></ul>
        <h2>Attributes <div id="search-attributes-icon"></div></h2>
        <div id="search-attributes-form"></div>
        <ul id="attributes" class="y-fill scroll"></ul>
      </div>
    """).appendTo '#container'

    new Button '#add-service',    ICONS.plus
    new Button '#remove-service', ICONS.minus

    $('#alpha-controls div').remove() unless @api.user.permissions.services

    this.drawBlankSlate()

    $('#add-service').click           => this.drawEditor()
    $('#remove-service').click        => this.toggleForm '#remove-service-form'
    $('#remove-service-cancel').click => this.toggleForm '#remove-service-form'
    $('#remove-service-form').submit  => this.deleteService()

    this.operators()
    this.findServices()
    this.findAttributes()
    this.findUsers()

    $('#container').show()
    @layout = this.resize()

    fn = =>
      @layout.resize()
      @layout.resize() # not sure why two are needed

    new Filter
      list: '#services'
      icon: '#search-services-icon'
      form: '#search-services-form'
      attrs: ['data-name']
      open:  fn
      close: fn

    new Filter
      list: '#attributes'
      icon: '#search-attributes-icon'
      form: '#search-attributes-form'
      attrs: ['data-name']
      open:  fn
      close: fn

  drawEditor: (service) ->
    return unless this.pageVisible()

    unless service
      @selectedService = null
      $('#services li').removeClass 'selected'

    $('#beta').empty()
    $("""
      <form id="editor-form" class="sections y-fill scroll">
        <input id="id" type="hidden"/>
        <div>
          <section>
            <h2>Service</h2>
            <fieldset>
              <label for="name">Name</label>
              <input id="name" type="text"/>
              <p id="name-error" class="error"></p>
              <label for="syntax">Criteria</label>
              <textarea id="syntax" placeholder="fqdn starts with 'www.' and platform is 'mac_os_x'"></textarea>
              <p id="syntax-status"></p>
            </fieldset>
          </section>
          <section>
            <h2>Members</h2>
            <fieldset id="service-preview">
              <ul id="members" class="scroll"></ul>
            </fieldset>
          </section>
          <section>
            <h2>Permissions</h2>
            <fieldset>
              <label>Users</label>
              <ul id="users" class="scroll"></ul>
              <label for="unix-users">Unix Accounts</label>
              <input id="unix-users" type="text"/>
              <p id="unix-users-error" class="error"></p>
              <p class="hint">Comma separated user names like: apache, postgres, root, etc.</p>
            </fieldset>
          </section>
        </div>
      </form>
      <form id="editor-buttons">
        <input id="save" type="submit" value="Save"/>
      </form>
    """).appendTo '#beta'

    if service
      this.findMembers(service.id)
      $('#id').val service.id
      $('#name').val service.name
      $('#syntax').val service.code
      $('#unix-users').val service.accounts.join(', ')

    this.drawUsers() if @users.length > 0

    @layout.resize()
    $('#name').focus()

    $('#syntax').change         => this.validateIn()
    $('#syntax').keyup          => this.validateIn()
    $('#editor-form').submit    => this.save()
    $('#editor-buttons').submit => this.save()

  drawUsers: ->
    return unless this.editorVisible()

    $('#users').empty()
    for user in @users
      node = $("""
        <li>
          <input id='user-#{user.jid}' type='checkbox' value='#{user.jid}'/>
          <label for='user-#{user.jid}'>#{user.jid}</label>
        </li>
      """).appendTo '#users'
      # user creating service gets access to it by default
      $('input', node).prop 'checked', true if user.jid == @session.bareJid()

    if @selectedService
      $('#users input[type="checkbox"]').val @selectedService.users

  toggleForm: (form, fn) ->
    form = $(form)
    $('form.overlay').each ->
      $(this).hide() unless this.id == form.attr 'id'
    if form.is ':hidden'
      fn() if fn
      form.fadeIn 100
    else
      form.fadeOut 100, ->
        form[0].reset()
        fn() if fn

  pageVisible: -> $('#services-page').length > 0

  editorVisible: -> $('#services-page #editor-form').length > 0

  resize: ->
    a   = $ '#alpha'
    b   = $ '#beta'
    c   = $ '#charlie'
    new Layout ->
      c.css 'left', a.width() + b.width()
