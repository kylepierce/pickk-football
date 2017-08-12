_ = require "underscore"
Match = require "mtr-match"
Promise = require "bluebird"
Task = require "../Task"
Game = require "../../model/Game"
EndOfGame = require "./EndOfGame"
Inning = require "./Inning"
AtBat = require "./AtBat"
Pitches = require "./Pitches"
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
    @Teams = dependencies.mongodb.collection("teams")
    @Players = dependencies.mongodb.collection("players")
    @Questions = dependencies.mongodb.collection("questions")
    @AtBats = dependencies.mongodb.collection("atBat")
    @Answers = dependencies.mongodb.collection("answers")
    @GamePlayed = dependencies.mongodb.collection("gamePlayed")
    @Users = dependencies.mongodb.collection("users")
    @Notifications = dependencies.mongodb.collection("notifications")
    @gameParser = new GameParser dependencies
    @endOfGame = new EndOfGame dependencies
    @Inning = new Inning dependencies
    @AtBat = new AtBat dependencies
    @Pitches = new Pitches dependencies

  execute: (old, update) ->
    result = @gameParser.getPlay update
    console.log result

    # if result
    #   Promise.bind @
        # .then -> @checkGameStatus old, result
        # .then -> @updateOld old, result
        # .then -> @detectChange old, result
        # .then (parms) -> @generateQuestions parms
        # .return true
        # .catch (error) =>
        #   @logger.error error.message, _.extend({stack: error.stack}, error.details)

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
    parms =
      gameId: old['_id']
      gameName: old['name']
      commerical: result['commerical']
      inning: result['eventStatus']['inning']
      inningDivision: result['eventStatus']['inningDivision']
      lastCount: result['old']['lastCount']
      oldStuff: old['old']['eventStatus']
      newStuff: result['old']['eventStatus']
      newInning: result['old']['inningDivision']
      newPlayer: result['eventStatus']['currentBatter']
      newEventId: result['old']['eventId']
      oldInning: if old['old'] then old['old']['inningDivision'] else "Top"
      oldPlayer: if old['old'] then old["old"]['player'] else 0
      oldEventId: if old['old'] then old['old']['eventId'] else 0
      oldPitch: if old['old'] then old["old"]['lastCount'].length else 0
      newPitch: result["old"]['lastCount'].length
      onIgnoreList: (ignoreList.indexOf result['old']['eventId'])
      pitch: (_.last result["old"]['lastCount'])
      pitchNumber: result['old']['lastCount'].length #Make this zero if its a new batter or inning.

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
    #gameId, inning, oldPlayer, newPlayer, eventCount, diff, pitch, pitchNumber,
    Promise.bind @
      # .then -> @checkCommericalStatus parms
      # .then -> @Inning.execute parms
      .then -> @AtBat.execute parms.gameId, parms.inning, parms.oldPlayer, parms.newPlayer, parms.eventCount, parms.diff
      .then -> @Pitches.execute parms.gameId, parms.pitch, parms.pitchNumber, parms.diff, parms.pitchDiff, parms.oldPlayer, parms.newPlayer
      # .then -> @endOfGame.execute parms.gameId, game['close_processed']

  checkCommericalStatus: (game) ->
    # Add something to kick out of commerical if a play is active.
    # if game
    #   Promise.bind @
    #     .then -> @Games.update {_id: game['_id']}, {$set: {commercial: false}, $set: {commercialStartedAt: 1}}
    #     .then -> @Games.find {_id: game['_id']}
    #     .tap (result) -> console.log result['commercial']
      # console.log "commercial not set", game['gameId']

      # thisGame = @Games.find {_id: game['gameId']}
      # console.log thisGame

    # now = moment()
    # timeout = now.diff(game.commercialStartedAt, 'minute')
    # commercialTime = @dependencies.settings['common']['commercialTime']
    # if timeout >= commercialTime
    #   Promise.bind @
    #     .then -> @Games.update {_id: game['gameId']}, {$set: {commercial: false}, $unset: {commercialStartedAt: 1}}
    #     .then -> @inning.closeActiveCommercialQuestions game['gameId'], game['gameName']
        # .tap -> @logger.verbose "Creating first player questions."
        # .then -> @createPitch old, update[0], newPlayer, 0
        # .tap -> @logger.verbose "Created 0-0"
        # .then -> @createAtBat old, update[0], newPlayer
        # gameId, atBatId, player, inning, eventCount
        # .tap -> @logger.verbose "Created New At Bat After Commercial"
