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

    @api = @dependencies.stats
    @Games = dependencies.mongodb.collection("games")

  execute: (eventId) ->
    Match.check eventId, Number

    
    @logger = @dependencies.logger

    Promise.bind @
      .then -> @api.getPlayByPlay eventId
      .then (result) -> result.apiResults[0].league.season.eventType[0].events
      .map @upsertGame

  upsertGame: (game) ->
    game = new Game game
    @Games.update {eventId: game.eventId}, {$set: game}, {upsert: true}
    return game

  getGameOdds: () ->
    Promise.bind @
      .then -> @api.getTeamLeaders(350);
      .then (result) -> console.log(result.apiResults[0].league.season.eventType[0])
      # .lineEvents[0].lines[0]) 