_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Task = require "../Task"
Game = require "../../model/Game"
UpdateTeam = require "../../task/stats/UpdateTeam"
dateFormat = require 'dateformat' #🚨

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      stats: Match.Any
      mongodb: Match.Any

    @api = @dependencies.stats
    @logger = @dependencies.logger
    @Games = @dependencies.mongodb.collection("games")
    @updateTeam = new UpdateTeam dependencies

    @registerEvents ['upserted']

  execute: ->
    Promise.bind @
    .then -> @api.getScheduledGames 7
    .then (result) -> result.apiResults[0].league.season.eventType[0].events
    .map @upsertGame
    .return true

  upsertGame: (data) ->
    game = new Game data

    Promise.bind @
      .then -> @Games.findOne game.getSelector()
      .then (found) ->
        if not found
          gameName = game.name
          @logger.verbose "Inserting Game " + gameName
          game["_id"] = @Games.db.ObjectId().toString()
          Promise.bind @
          .then ->
            @Games.insert game
      .then (original) ->
        game['close_processed'] = false if @isClosing original, game #close the game if  'completed' is true
        @Games.update game.getSelector(), {$set: game}, {upsert: true} #🤔
        .then => @emit "upserted", game

  isClosing: (original, game) -> original and not original['completed'] and game['completed']
