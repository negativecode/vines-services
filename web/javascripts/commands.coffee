class Commands
  constructor: ->
    @buf = []
    @index = 0

  prev: ->
    val = @buf[--@index]
    @index = -1 unless val
    val || ''

  next: ->
    val = @buf[++@index]
    @index = @buf.length unless val
    val || ''

  push: (cmd) ->
    @buf.push cmd
    @index = @buf.length
