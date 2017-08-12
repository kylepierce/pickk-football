_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Task = require "../Task"
Game = require "../../model/Game"

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      stats: Match.Any
      mongodb: Match.Any

    @Games = dependencies.mongodb.collection("atBat")

  execute: (gameId) ->
    Match.check gameId, Number

    api = @dependencies.stats
    @logger = @dependencies.logger


    Promise.bind @
    .then -> api.getPlayByPlay gameId
    .then (result) -> result.apiResults[0].league.season.eventType[0].events
    # .tap (result) -> @logger.verbose result
    # .tap (result) -> @logger.verbose "Batter: #{result[0]['eventStatus']['currentBatter']['playerId']} - #{result[0]['eventStatus']['balls']} - #{result[0]['eventStatus']['strikes']}"
    .map @upsertGame

  upsertGame: (game) ->
    game = new Game game
    collection = @dependencies.mongodb.collection("games")
    @Games.update {eventId: game.eventId}, {$set: Game}, {upsert: true}
    return game
