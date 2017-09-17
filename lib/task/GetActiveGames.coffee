_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Task = require "./Task"
moment = require "moment"

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    @Games = @dependencies.mongodb.collection("games")
    @logger = @dependencies.logger

  execute: ->
    Promise.bind @
      .then -> @Games.find {sport: "NFL", manual: {$exists: false}, $or: [{status: "In-Progress"}, {close_processed: false}]}

  preGame: ->
    now = moment().toISOString()
    soon = moment().add(30, "m").toISOString()
    Promise.bind @
      .then -> @Games.find {sport: "NFL", status: "Pre-Game", pre_game_processed: {$exists: false}, iso: {$lt: soon}}

      # "2017-09-17T21:00:00.000Z" - at T20:30 I want to create questions and send out a push.

      # $gte: ISODate("2010-04-29T00:00:00.000Z"),
      #
