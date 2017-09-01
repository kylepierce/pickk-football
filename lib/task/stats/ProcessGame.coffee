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
CreatePlayQuestions = require "./CreatePlayQuestions"
GetPlayDetails = require "./GetPlayDetails"
CloseInactiveQuestions = require "./CloseInactiveQuestions"

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    @logger = @dependencies.logger
    @Games = dependencies.mongodb.collection("games")
    @Multipliers = dependencies.mongodb.collection("multipliers")
    @Questions = dependencies.mongodb.collection("questions")
    @Teams = dependencies.mongodb.collection("teams")
    @Answers = dependencies.mongodb.collection("answers")
    @GamePlayed = dependencies.mongodb.collection("gamePlayed")
    @Users = dependencies.mongodb.collection("users")
    @Notifications = dependencies.mongodb.collection("notifications")
    @closeInactiveQuestions = new CloseInactiveQuestions dependencies
    @createPlayQuestions = new CreatePlayQuestions dependencies
    @endOfGame = new EndOfGame dependencies
    @getPlayDetails = new GetPlayDetails dependencies

  execute: (old, update) ->
    @checkCommercialStatus old._id, old.commercialTime

    if old.pbp
      oldPlays = old.pbp.length
      newPlays = update.pbp.length
    if @isNewPlay newPlays, oldPlays
      teams = update.teams
      previousPlay = (_.last update.pbp)
      playDetails = @getPlayDetails.execute previousPlay, teams

      Promise.bind @
        .then -> @closeInactiveQuestions.execute update.id, teams
        .then -> @gameInProgress old._id
        .then -> @startCommercialBreak old._id, playDetails
        # .then -> @createCommercialQuestions update.eventId, previousPlayDetail
        .then -> @createPlayQuestions.execute update.eventId, playDetails

  isNewPlay: (newLength, oldLength) ->
    if newLength > oldLength
      return true

  createCommercialQuestions: (eventId, previous) ->

  startCommercialBreak: (gameId, previous) ->
    list = ["Punt", "Touchdown", "Field Goal", "Kickoff", "Timeout", "Two Min"]
    if (list.indexOf(previous.playDetails.type) > 0)
      Promise.bind @
        .then -> @Games.update({_id: gameId}, {$set: {commercial: true, commercialTime: new Date}})

  checkCommercialStatus: (gameId, oldTime) ->
    newTime =  new Date
    commercialBreak = @dependencies.settings['common']['commercialTime']
    if oldTime
      oldTime = new Date moment(oldTime).add commercialBreak, "seconds"
      if newTime > oldTime
        @endCommercialBreak gameId

  gameInProgress: (gameId) ->
    Promise.bind @
      .then -> @getGame gameId
      .then (game) ->
        if game.commercial is true
          console.log "Game has resumed already!!"
          @endCommercialBreak gameId

  endCommercialBreak: (gameId) ->
    console.log "Ending Commercial Break"
    Promise.bind @
      .then -> @Games.update({_id: gameId}, {$set: {commercial: false}, $unset: {commercialTime: 1}})

  getGame: (gameId) ->
    Promise.bind @
      .then -> @Games.findOne {_id: gameId}
