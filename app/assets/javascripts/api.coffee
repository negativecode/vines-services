class @Api
  USERS = 'http://getvines.com/protocol/users'

  constructor: (@session) ->
    @user = null
    @session.onRoster =>
      this.get USERS, jid: @session.bareJid(), (result) =>
        @user = result

  jid: -> "vines.#{@session.bareJid().split('@')[1]}"

  get: (ns, criteria, callback) ->
    node = @session.xml """
      <iq id="#{@session.uniqueId()}" to="#{this.jid()}" type="get">
        <query xmlns="#{ns}"/>
      </iq>
    """
    $('query', node).attr key, value for key, value of criteria

    @session.sendIQ node, (result) =>
      ok = $(result).attr('type') == 'result'
      return unless ok
      callback JSON.parse $('query', result).text()

  get2: (ns, body, callback) ->
    node = @session.xml """
      <iq id="#{@session.uniqueId()}" to="#{this.jid()}" type="get">
        <query xmlns="#{ns}"/>
      </iq>
    """
    $('query', node).text body
    @session.sendIQ node, (result) =>
      ok = $(result).attr('type') == 'result'
      return unless ok
      callback JSON.parse $('query', result).text()

  remove: (ns, id, callback) ->
    node = @session.xml """
      <iq id="#{@session.uniqueId()}" to="#{this.jid()}" type="set">
        <query xmlns="#{ns}" action="delete" id=""/>
      </iq>
    """
    $('query', node).attr 'id', id
    @session.sendIQ node, callback

  save: (ns, obj, callback) ->
    node = @session.xml """
      <iq id="#{@session.uniqueId()}" to="#{this.jid()}" type="set">
        <query xmlns="#{ns}"/>
      </iq>
    """
    $('query', node).text JSON.stringify obj

    @session.sendIQ node, (result) =>
      ok = $(result).attr('type') == 'result'
      return unless ok
      callback JSON.parse $('query', result).text()
