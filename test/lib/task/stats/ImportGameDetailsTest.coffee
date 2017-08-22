createDependencies = require "../../../../helper/dependencies"
settings = (require "../../../../helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")
Promise = require "bluebird"
moment = require "moment"
ImportGameDetails = require "../../../../lib/task/stats/ImportGameDetails"
loadFixtures = require "../../../../helper/loadFixtures"
GamesFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/importGameDetails/collection/Games.json"
GamesWithInningsFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/importGameDetails/collection/GamesWithInnings.json"

# describe "Import details information about a game specified to Mongo", ->
#   dependencies = createDependencies settings, "PickkImport"
#   mongodb = dependencies.mongodb
#
#   importGameDetails = new ImportGameDetails dependencies
#   Games = mongodb.collection("games")
#
#   gameId = "fec58a7a-eff7-4eec-9535-f64c42cc4870"
#
#   beforeEach ->
#     Promise.bind @
#     .then ->
#       Promise.all [
#         Games.remove()
#       ]
#
#   it 'should set game details for a game in the first time', ->
#
#     new Promise (resolve, reject) ->
#       nock.back "test/fixtures/task/stats/importGameDetails/request/game.json", (recordingDone) ->
#         Promise.bind @
#         .then -> loadFixtures GamesFixtures, mongodb
#         .then -> Games.findOne({"id": gameId})
#         .then (game) ->
#           # ensure the game has no innings at all
#           should.exist game
#
#           {innings} = game
#           should.not.exist innings
#         .then -> importGameDetails.execute gameId
#         .then -> Games.findOne({"id": gameId})
#         .then (game) ->
#           # ensure innings have been added
#           should.exist game
#
#           {innings} = game
#           should.exist innings
#           innings.length.should.be.equal 10
#         .then @assertScopesFinished
#         .then resolve
#         .catch reject
#         .finally recordingDone
#
#   it 'should update game details for a game in progress', ->
#     new Promise (resolve, reject) ->
#       nock.back "test/fixtures/task/stats/importGameDetails/request/game.json", (recordingDone) ->
#         Promise.bind @
#         .then -> loadFixtures GamesWithInningsFixtures, mongodb
#         .then -> Games.findOne({"id": gameId})
#         .then (game) ->
#           # ensure the game contains only one inning at the moment
#           should.exist game
#
#           {innings} = game
#           should.exist innings
#           innings.length.should.be.equal 1
#         .then -> importGameDetails.execute gameId
#         .then -> Games.findOne({"id": gameId})
#         .then (game) ->
#           # ensure innings have been added
#           should.exist game
#
#           {innings} = game
#           should.exist innings
#           innings.length.should.be.equal 10
#         .then @assertScopesFinished
#         .then resolve
#         .catch reject
#         .finally recordingDone
