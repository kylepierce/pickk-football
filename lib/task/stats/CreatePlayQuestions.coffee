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
    @Multipliers = dependencies.mongodb.collection("multipliers")
    @Questions = dependencies.mongodb.collection("questions")
    @Teams = dependencies.mongodb.collection("teams")
    @Answers = dependencies.mongodb.collection("answers")
    @GamePlayed = dependencies.mongodb.collection("gamePlayed")
    @Users = dependencies.mongodb.collection("users")
    @Notifications = dependencies.mongodb.collection("notifications")
    @gameParser = new GameParser dependencies
    @endOfGame = new EndOfGame dependencies

  execute: (gameId, details) ->
    Promise.bind @
      .then -> @Multipliers.findOne(details.multiplierArguments)
      .then (result) -> @parseOptions result.options
      .then (options) -> @insertPlayQuestion gameId, details, options
      .tap (result) -> @logger.verbose "Creating Question: [", result.gameId, "]", result.que, details.nextPlay
      .then (result) -> return result

  parseOptions: (options) ->
    _.mapObject options, (option, key) ->
      if _.isEmpty option
        delete options[key]
        return false

      max = option.high
      min = option.low
      multi = (Math.random() * (max-min) + min).toFixed(1)
      option.multiplier = parseFloat(multi)

    return options

  insertPlayQuestion: (gameId, details, options) ->
    Promise.bind @
      .then ->@Games.findOne({_id: gameId})
      .then (result) ->
        @Questions.insert
          _id: @Questions.db.ObjectId().toString()
          dateCreated: new Date()
          gameId: result._id
          period: result.period
          playId:  details.previous.playId
          details:  details.multiplierArguments
          type: "play"
          active: true
          commercial: false
          que: @generateQuestionTitle details
          options: options
          usersAnswered: []

  generateQuestionTitle: (play) ->
    if !play
      @logger.verbose "No play??"
    else if !play.nextPlay
      @logger.verbose "No next play data"
    else if play.nextPlay.playType is "PAT"
      que = "Point After Attempt"
    else if play.nextPlay.playType is "Kickoff"
      que = "Kickoff"
    else if play.nextPlay.playType is "Off Penalty"
      downGrammer = @downGrammer play.nextPlay.down
      que =  downGrammer + " & " + play.nextPlay.distance + " Yards"
    else if play.nextPlay.playType is "First Down"
      downGrammer = @downGrammer 1
      que =  downGrammer + " & " + play.nextPlay.distance + " Yards"
    else
      downGrammer = @downGrammer play.nextPlay.down
      que =  downGrammer + " & " + play.distance.yardsToFirstDown + " Yards"
    return que

  downGrammer: (down) ->
    switch down
      when 1
        return "1st"
      when 2
        return "2nd"
      when 3
        return "3rd"
      when 4
        return "4th"
