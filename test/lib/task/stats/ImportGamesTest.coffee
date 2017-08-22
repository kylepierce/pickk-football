createDependencies = require "../../../../helper/dependencies"
settings = (require "../../../../helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")
Promise = require "bluebird"
moment = require "moment"
ImportGames = require "../../../../lib/task/stats/ImportGames"
loadFixtures = require "../../../../helper/loadFixtures"
GamesFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/importGames/collection/Games.json"
inactualClosedGameFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/importGames/collection/InactualClosedGame.json"
closedGameFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/importGames/collection/ClosedGame.json"
GamesWithInningsFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/importGames/collection/GamesWithInnings.json"

# describe "Import brief information about games for date specified from stats to Mongo", ->
#   dependencies = createDependencies settings, "PickkImport"
#   mongodb = dependencies.mongodb
#
#   importGames = undefined
#   Games = mongodb.collection("games")
#
#   date = moment("2016-06-12").toDate() # in fact 2016-06-11 because of time zone shift
#   gameId = "fec58a7a-eff7-4eec-9535-f64c42cc4870"
#   closedGameId = "69383e6a-7b67-486c-8f36-52f174a42c62"
#   closedGameDate = moment("2016-08-02").toDate() # in fact 2016-08-01 because of time zone shift
#
#   beforeEach ->
#     importGames = new ImportGames dependencies
#
#     Promise.bind @
#     .then ->
#       Promise.all [
#         Games.remove()
#       ]
#
#   it 'should import games into the clear collection', ->
#     gameNumber = undefined
#     @timeout 10000
#
#     new Promise (resolve, reject) ->
#       nock.back "test/fixtures/task/stats/importGames/request/games.json", (recordingDone) ->
#         Promise.bind @
#         .then -> dependencies.stats.getScheduledGames date
#         .then (result) -> gameNumber = result.league.games.length
#         .then -> importGames.execute(date)
#         .then -> Games.count()
#         .then (count) ->
#           # ensure amount of games is right
#           count.should.be.equal gameNumber
#         .then -> Games.findOne({"id": gameId})
#         .then (result) ->
#           # ensure some game has been added properly
#           should.exist result
#
#           {status} = result
#           should.exist status
#           status.should.be.equal "closed"
#
#           {home} = result
#           should.exist home
#           home.should.be.an "object"
#
#           {name} = home
#           should.exist name
#           name.should.be.equal "White Sox"
#         .then @assertScopesFinished
#         .then resolve
#         .catch reject
#         .finally recordingDone
#
#   it 'should update existing and insert new games into the collection', ->
#     gameNumber = undefined
#
#     new Promise (resolve, reject) ->
#       nock.back "test/fixtures/task/stats/importGames/request/games.json", (recordingDone) ->
#         Promise.bind @
#         .then -> loadFixtures GamesFixtures, mongodb
#         .then -> Games.findOne({"id": gameId})
#         .then (result) ->
#           # ensure "Key" is corrupted
#           should.exist result
#
#           {status} = result
#           should.exist status
#           status.should.be.equal "In-Progress"
#         .then -> dependencies.stats.getScheduledGames date
#         .then (result) -> gameNumber = result.league.games.length
#         .then -> importGames.execute(date)
#         .then -> Games.count()
#         .then (count) ->
#           # ensure amount of games is right
#           count.should.be.equal gameNumber
#         .then -> Games.findOne({"id": gameId})
#         .then (result) ->
#           # ensure some game has been added properly
#           should.exist result
#
#           {status} = result
#           should.exist status
#           status.should.be.equal "closed"
#
#           {home} = result
#           should.exist home
#           home.should.be.an "object"
#
#           {name} = home
#           should.exist name
#           name.should.be.equal "White Sox"
#         .then @assertScopesFinished
#         .then resolve
#         .catch reject
#         .finally recordingDone
#
#   it 'shouldn\'t drop data fetched by other calls before', ->
#     new Promise (resolve, reject) ->
#       nock.back "test/fixtures/task/stats/importGames/request/single.json", (recordingDone) ->
#         Promise.bind @
#         .then -> loadFixtures GamesWithInningsFixtures, mongodb
#         .then -> Games.findOne({"id": gameId})
#         .then (game) ->
#           # ensure the game contains innings
#           should.exist game
#
#           {innings} = game
#           should.exist innings
#           innings.should.be.an "array"
#           innings.length.should.be.equal 1
#         .then -> importGames.execute(date)
#         .then -> Games.findOne({"id": gameId})
#         .then (game) ->
#           # ensure innings hasn't been override
#           should.exist game
#
#           {innings} = game
#           should.exist innings
#           innings.should.be.an "array"
#           innings.length.should.be.equal 1
#         .then @assertScopesFinished
#         .then resolve
#         .catch reject
#         .finally recordingDone
#
#   it 'should emit event for each upserted game', ->
#     spy = sinon.spy()
#     importGames.observe "upserted", spy
#
#     new Promise (resolve, reject) ->
#       nock.back "test/fixtures/task/stats/importGames/request/single.json", (recordingDone) ->
#         Promise.bind @
#         .then -> importGames.execute(date)
#         .then ->
#           spy.should.have.callCount 15
#         .then @assertScopesFinished
#         .then resolve
#         .catch reject
#         .finally recordingDone
#
#   it 'should mark the game as "closing" when its state is changed to "closed"', ->
#     new Promise (resolve, reject) ->
#       nock.back "test/fixtures/task/stats/importGames/request/closed_game.json", (recordingDone) ->
#         Promise.bind @
#         .then -> loadFixtures inactualClosedGameFixtures, mongodb
#         .then -> Games.findOne({"id": closedGameId})
#         .then (game) ->
#           should.exist game
#
#           {status, completed} = game
#           should.exist status
#           status.should.be.equal "In-Progress"
#
#           should.exist completed
#           completed.should.be.equal false
#         .then -> importGames.execute closedGameDate
#         .then -> Games.findOne({"id": closedGameId})
#         .then (game) ->
#           should.exist game
#
#           {status, completed, close_processed} = game
#           should.exist status
#           status.should.be.equal "closed"
#
#           should.exist completed
#           completed.should.be.equal true
#
#           should.exist close_processed
#           close_processed.should.be.equal false
#         .then @assertScopesFinished
#         .then resolve
#         .catch reject
#         .finally recordingDone
#
#   it 'shouldn\'t set "close_processed" if the game is already closed', ->
#     new Promise (resolve, reject) ->
#       nock.back "test/fixtures/task/stats/importGames/request/closed_game.json", (recordingDone) ->
#         Promise.bind @
#         .then -> loadFixtures closedGameFixtures, mongodb
#         .then -> importGames.execute closedGameDate
#         .then -> Games.findOne({"id": closedGameId})
#         .then (game) ->
#           should.exist game
#
#           {close_processed} = game
#           should.not.exist close_processed
#         .then @assertScopesFinished
#         .then resolve
#         .catch reject
#         .finally recordingDone
