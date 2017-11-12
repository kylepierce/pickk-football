_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Strategy = require "../Strategy"
ImportGameDetails = require "../../task/stats/ImportGameDetails"


module.exports = class extends Strategy
  constructor: (dependencies) ->
    super

    @mongodb = dependencies.mongodb
    @Games = dependencies.mongodb.collection("games")
    @importGameDetails = new ImportGameDetails dependencies
    @logger = dependencies.logger

  execute: () ->
    Promise.bind @
      .then -> @importGameDetails.getGameOdds()
      .then (result) -> console.log(result);
