_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Task = require "../Task"
Game = require "../../model/Game"
EndOfGame = require "./EndOfGame"
Team = require "../../model/Team"
Player = require "../../model/Player"
GameParser = require "./helper/GameParser"
moment = require "moment"
promiseRetry = require 'promise-retry'
chance = new (require 'chance')

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    @logger = @dependencies.logger
    @Games = dependencies.mongodb.collection("games")
    @Questions = dependencies.mongodb.collection("questions")
    @Answers = dependencies.mongodb.collection("answers")
    @GamePlayed = dependencies.mongodb.collection("gamePlayed")
    @Users = dependencies.mongodb.collection("users")
    @Notifications = dependencies.mongodb.collection("notifications")
    @gameParser = new GameParser dependencies
    @endOfGame = new EndOfGame dependencies

  execute: (old, update) ->
    result = @gameParser.getPlay update

    # if result
    #   Promise.bind @
    #     .then -> @checkGameStatus old, result
    #     .then -> @updateOld old, result
    #     .then -> @detectChange old, result
    #     .then (parms) -> @generateQuestions parms
    #     .return true
    #     .catch (error) =>
    #       @logger.error error.message, _.extend({stack: error.stack}, error.details)

  updateOld: (old, update) ->
    @Games.update {_id: old["_id"]}, {$set: update}

  checkGameStatus: (old, update) ->
    if !old['old']
      console.log "[Global] No old????????"
      @Games.update {_id: update.eventId}, {$set: update}

    else if !update
      console.log "[Global] No update????????"
      return

    else if update['eventStatus']['eventStatusId'] isnt 2
      console.log "Something is wrong. Shutting this whole thing down..."
      return

  detectChange: (old, result) ->
    ignoreList =  [35, 42, 89, 96, 97, 98]


    diff = []
    list = ["strikes", "balls", "outs", "currentBatter", "eventStatusId", "innings", "inningDivision", "runnersOnBase"]

    _.map list, (key) ->
      compare = _.isEqual parms.oldStuff[key], parms.newStuff[key]
      if not compare
        diff.push key

    parms.eventCount = result['old']["eventCount"]
    parms.eventId = result['old']['eventId']
    parms.diff = diff
    # parms.nextPlayer = if parms.inningDivision is "Top" then result['away']['liveState']['nextUpBatters'][0] else result['home']['liveState']['nextUpBatters'][0]
    # Strange it throws an error if there isnt a player. Seems when the switch its blank for 5 seconds.
    # if parms['newPlayer'] then parms.atBatId = parms.gameId + "-" + parms.inning + "-" + parms.eventCount + "-" + parms['newPlayer']['playerId']
    # parms.pitchDiff = parms.newPitch - parms.oldPitch

    return parms

  generateQuestions: (parms) ->
    Promise.bind @
