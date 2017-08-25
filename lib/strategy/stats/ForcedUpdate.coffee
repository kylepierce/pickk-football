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

    playNumber = 7
    old.pbp = _.first plays, playNumber
    update.pbp = _.first plays, playNumber + 1
    Promise.bind @
      .then -> @importGameDetails.upsertGame old
      .then -> @increasePlays old, update

  increasePlays: (old, update) ->
    Promise.bind @
      .then -> @importGameDetails.upsertGame update
      .then (result) -> @processGame.execute old, result

  getGame: (gameId) ->
    Promise.bind @
      .then -> @Games.find {_id: gameId}
