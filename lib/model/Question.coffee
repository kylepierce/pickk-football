Match = require "mtr-match"
_ = require "underscore"

module.exports = class
  constructor: (data) ->
    Match.check data, Object

    @que = data.que
    @option = data.options
    @updatedAt = new Date()

  getSelector: ->
    "_id": @_id
