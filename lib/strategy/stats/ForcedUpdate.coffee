_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Strategy = require "../Strategy"
ImportGames = require "../../task/stats/ImportGames"
GetActiveGames = require "../../task/GetActiveGames"
ImportGameDetails = require "../../task/stats/ImportGameDetails"
ProcessGame = require "../../task/stats/ProcessGame"
promiseRetry = require 'promise-retry'
Game = require "../../model/Game"
full = require "../../../test/fixtures/task/stats/processGame/collection/FullGame.json"
base = require "../../../test/fixtures/task/stats/processGame/collection/base.json"
baseWithPlays = require "../../../test/fixtures/task/stats/processGame/collection/baseWithPlays.json"

module.exports = class extends Strategy
  constructor: (dependencies) ->
    super

    @mongodb = dependencies.mongodb
    @Games = dependencies.mongodb.collection("games")
    @importGames = new ImportGames dependencies
    @getActiveGames = new GetActiveGames dependencies
    @importGameDetails = new ImportGameDetails dependencies
    @processGame = new ProcessGame dependencies
    @logger = dependencies.logger

  execute: () ->
    old = base.games[0]
    update = baseWithPlays.games[0]
    fullGame = full.games[0]
    plays = fullGame.pbp

    # playNumber = 6
    # old.pbp = _.first plays, playNumber
    # update.pbp = _.first plays, playNumber + 1
    Promise.bind @
      # .then -> @resetGame
      .then -> @getPbpLength old.eventId
      .then (playNumber) ->
        old.pbp = _.first plays, playNumber
        update.pbp = _.first plays, playNumber + 1
      .then -> @increasePlays old, update
      .catch (error) =>
        @logger.error error.message, _.extend({stack: error.stack}, error.details)
        retry error

  resetGame: ->
    Promise.bind @
      .then -> @importGameDetails.upsertGame base.games[0]

  increasePlays: (old, update) ->
    Promise.bind @
      .then -> @importGameDetails.upsertGame update
      .then (result) -> @processGame.execute old, result

  getPbpLength: (eventId) ->
    Promise.bind @
      .then -> @Games.findOne({eventId: eventId})
      .then (game) -> game.pbp.length
