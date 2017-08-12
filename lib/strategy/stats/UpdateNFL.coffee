_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Strategy = require "../Strategy"
ImportGames = require "../../task/stats/ImportGames"
GetActiveGames = require "../../task/GetActiveGames"
ImportGameDetails = require "../../task/stats/ImportGameDetails"
CloseInactiveAtBats = require "../../task/CloseInactiveAtBats"
CloseInactiveQuestions = require "../../task/CloseInactiveQuestions"
ProcessGame = require "../../task/stats/ProcessGame"
promiseRetry = require 'promise-retry'

module.exports = class extends Strategy
  constructor: (dependencies) ->
    super

    @importGames = new ImportGames dependencies
    @getActiveGames = new GetActiveGames dependencies
    @importGameDetails = new ImportGameDetails dependencies
    @closeInactiveAtBats = new CloseInactiveAtBats dependencies
    @closeInactiveQuestions = new CloseInactiveQuestions dependencies
    @processGame = new ProcessGame dependencies

    @logger = dependencies.logger

  execute: ->
    Promise.bind @
      .then -> @importGames.execute()
      .then -> @getActiveGames.execute()
      .map (game) ->
        Promise.bind @
        .then -> @importGameDetails.execute game['eventId']
        .then (result) -> @processGame.execute game, result[0]
      , {concurrency: 1}
