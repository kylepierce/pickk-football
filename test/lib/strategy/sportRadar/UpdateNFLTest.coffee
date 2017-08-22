createDependencies = require "../../../../helper/dependencies"
settings = (require "../../../../helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")
Promise = require "bluebird"
moment = require "moment"
ImportGames = require "../../../../lib/task/stats/ImportGames"
loadFixtures = require "../../../../helper/loadFixtures"
GamesFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/importGames/collection/Games.json"
statsGame = require "../../../../lib/model/Game"

UpdateNFL = require "../../../../lib/strategy/stats/UpdateNFL"


describe "Import brief information about games for date specified from stats to Mongo", ->
  dependencies = createDependencies settings, "PickkImport"
  mongodb = dependencies.mongodb

  updateNFL = new UpdateNFL dependencies
  Games = mongodb.collection("games")

  beforeEach ->
    Promise.bind @
    .then ->
      Promise.all [
        Games.remove()
      ]
