_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Strategy = require "../Strategy"
ImportGames = require "../../task/stats/ImportGames"
GetActiveGames = require "../../task/GetActiveGames"
ImportGames = require "../../task/stats/ImportGames"
ImportGameDetails = require "../../task/stats/ImportGameDetails"
ProcessGame = require "../../task/stats/ProcessGame"
promiseRetry = require 'promise-retry'
Game = require "../../model/Game"
full = require "../../../test/fixtures/task/stats/processGame/collection/ChiVsAtl.json"
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
    fullGame = full.games[0]
    old = base.games[0]
    old.eventId = fullGame.eventId
    old.teams = fullGame.teams
    old.startDate = fullGame.startDate
    update = baseWithPlays.games[0]
    update.eventId = fullGame.eventId
    update.teams = fullGame.teams
    update.startDate = fullGame.startDate
    plays = fullGame.pbp

    # Promise.bind @
    #   .then -> @resetGame old

    Promise.bind @
      .then -> @getPbpLength old.eventId
      .then (playNumber) ->
        old.pbp = _.first plays, playNumber
        update.pbp = _.first plays, playNumber + 1
      .then -> @increasePlays old, update
      .catch (error) =>
        @logger.error error.message, _.extend({stack: error.stack}, error.details)

  resetGame: (old) ->
    Promise.bind @
      .then -> @importGames.upsertGame old

  increasePlays: (old, update) ->
    lastPlay = _.last update.pbp

    # Simulate live game event status info
    update.eventStatus.down = lastPlay.down
    update.eventStatus.distance = lastPlay.distance
    update.eventStatus.period = lastPlay.period
    update.location = lastPlay.endYardLine
    timeSplit = lastPlay.time.split ":"
    update.eventStatus.minutes = timeSplit[0]
    update.eventStatus.seconds = timeSplit[1]
    update['teams'][0].score = lastPlay.homeScoreAfter
    update['teams'][1].score = lastPlay.awayScoreAfter

    Promise.bind @
      .then -> @importGameDetails.upsertGame update
      .then (result) -> @processGame.execute old, result

  getPbpLength: (eventId) ->
    Promise.bind @
      .then -> @Games.findOne({eventId: eventId})
      .then (game) -> return game.pbp.length
