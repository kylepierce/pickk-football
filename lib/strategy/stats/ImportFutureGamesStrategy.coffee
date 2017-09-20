_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Strategy = require "../Strategy"
ImportGames = require "../../task/stats/ImportGames"
promiseRetry = require 'promise-retry'
moment = require 'moment'

module.exports = class extends Strategy
  constructor: (dependencies) ->
    super
    @importGames = new ImportGames dependencies
    @logger = dependencies.logger

  execute: ->
    # do not allow it to crash!
    promiseRetry {retries: 1000, factor: 1}, (retry) =>
      Promise.bind @
      .then ->  @importGames.execute()
      .catch (error) =>
        @logger.error error.message, _.extend({stack: error.stack}, error.details)
        retry error
