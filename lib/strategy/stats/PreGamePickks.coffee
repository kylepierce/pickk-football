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

module.exports = class extends Strategy
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    # @mongodb = dependencies.mongodb
    @Games = dependencies.mongodb.collection("games")
    @importGames = new ImportGames dependencies
    @getActiveGames = new GetActiveGames dependencies
    @importGameDetails = new ImportGameDetails dependencies
    @processGame = new ProcessGame dependencies
    @logger = dependencies.logger

  execute: ->
    Promise.bind @
      .then -> @getActiveGames.preGame()
      .map (game) ->
        Promise.bind @
          .then -> @Games.update({_id: game._id}, {$set: {pre_game_processed: true}})
        # console.log game.name, game.iso
        # Promise.bind @
        #   .then -> @importGameDetails.execute game['eventId']
        #   .then (result) -> @processGame.execute game, result[0]
