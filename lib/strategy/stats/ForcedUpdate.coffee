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
base = require "../../../test/fixtures/task/stats/processGame/collection/base.json"
kickoff = require "../../../test/fixtures/task/stats/processGame/collection/kickoff.json"
newPlay = require "../../../test/fixtures/task/stats/processGame/collection/FullGameNewPlay.json"


module.exports = class extends Strategy
  constructor: (dependencies) ->
    super

    @mongodb = dependencies.mongodb

    @importGames = new ImportGames dependencies
    @getActiveGames = new GetActiveGames dependencies
    @importGameDetails = new ImportGameDetails dependencies
    @processGame = new ProcessGame dependencies
    @logger = dependencies.logger
    old = old

  execute: ->
    base = base.games[0]
    kickoff = kickoff.games[0]
    # firstDown = firstDown.games[0]
    # secondDown = secondDown.games[0]
    # thirdDown = thirdDown.games[0]
    # punt = punt.games[0]
    # fieldGoal = fieldGoal.games[0]
    Promise.bind @
      .then -> @importGameDetails.upsertGame kickoff
      .then (result) -> @processGame.execute base, result
