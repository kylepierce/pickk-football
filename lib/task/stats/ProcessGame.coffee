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
    @createPlayQuestions = new CreatePlayQuestions dependencies
    @endOfGame = new EndOfGame dependencies
    @getPlayDetails = new GetPlayDetails dependencies

  execute: (old, update) ->
    if old.pbp
      oldPlays = old.pbp.length
      newPlays = update.pbp.length
    if @isNewPlay newPlays, oldPlays
      teams = update.teams
      previousPlay = (_.last update.pbp)
      playDetails = @getPlayDetails.execute previousPlay, teams

      Promise.bind @
        # .then -> @closeInactiveQuestions update.id, teams
        # .then -> @createCommercialQuestions update.eventId, previousPlayDetails
        # .then -> @startCommercialBreak update.eventId, previousPlayDetails
        .then -> @createPlayQuestions.execute update.eventId, playDetails

  isNewPlay: (newLength, oldLength) ->
    if newLength > oldLength
      return true

  createCommercialQuestions: (eventId, previous) ->

  startCommercialBreak: (eventId, previous) ->
    list = ["Punt", "Touchdown", "Field Goal", "Kickoff", "Timeout", "Two Min"]
    if (list.indexOf(previous.playType) > 0)
      Promise.bind @
        .then -> getGame eventId
        .then (game) -> @Games.update({_id: game._id}, {$set: {commercial: true, commercialTime: new Date}})

  getGame: (gameId) ->
    Promise.bind @
      .then -> @Games.find {_id: gameId}
