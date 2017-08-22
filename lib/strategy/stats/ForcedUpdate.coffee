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
baseWithPlays = require "../../../test/fixtures/task/stats/processGame/collection/baseWithPlays.json"
kickoff = require "../../../test/fixtures/task/stats/processGame/collection/kickoff.json"
firstDown = require "../../../test/fixtures/task/stats/processGame/collection/firstDown.json"
firstDown1 = require "../../../test/fixtures/task/stats/processGame/collection/firstDown1.json"
secondDown = require "../../../test/fixtures/task/stats/processGame/collection/secondDown.json"
thirdDown = require "../../../test/fixtures/task/stats/processGame/collection/thirdDown.json"
punt = require "../../../test/fixtures/task/stats/processGame/collection/punt.json"
fieldGoal = require "../../../test/fixtures/task/stats/processGame/collection/fieldGoal.json"
pat = require "../../../test/fixtures/task/stats/processGame/collection/pat.json"

module.exports = class extends Strategy
  constructor: (dependencies) ->
    super

    @mongodb = dependencies.mongodb
    @importGames = new ImportGames dependencies
    @getActiveGames = new GetActiveGames dependencies
    @importGameDetails = new ImportGameDetails dependencies
    @processGame = new ProcessGame dependencies
    @logger = dependencies.logger

  execute: ->
    # existing = baseWithPlays.games[0]
    # newPlay = @combinedArrays firstDown1
    # firstDown1 = base.pbp.push(firstDown1)
    # console.log firstDown1
    kickoff = kickoff.games[0]
    firstDown = firstDown.games[0]
    secondDown = secondDown.games[0]
    thirdDown = thirdDown.games[0]
    punt = punt.games[0]
    fieldGoal = fieldGoal.games[0]
    pat = pat.games[0]
    Promise.bind @
      .then -> @importGameDetails.upsertGame punt
      .then (result) -> @processGame.execute firstDown, result

  combinedArrays: (newPlay) ->
    existing = baseWithPlays.games[0]
    newPlay.playId = 45.0
    existing.pbp.push(newPlay)
    return existing
