_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
moment = require "moment"
Task = require "../../Task"
Deep = require 'deep-diff'

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    @logger = @dependencies.logger
    @Games = dependencies.mongodb.collection("games")

  detectChange: (old, update) ->
    if update.pbp.length > old.pbp.length
      return _.last update.pbp
