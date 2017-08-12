Stats = require "../lib/api/Stats"
Match = require "mtr-match"

module.exports = (options) ->
  Match.check options, Object
  new Stats(options)
