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

  execute: (eventId, details) ->
    Promise.bind @
      .then -> @Multipliers.find details.multiplierArguments
      .then (result) -> @parseOptions result[0].options
      .then (options) -> @insertPlayQuestion eventId, details, options

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

  insertPlayQuestion: (eventId, details, options) ->
    console.log details
    Promise.bind @
      .then ->@Games.find {eventId: eventId}
      .then (result) ->
        @Questions.insert
          _id: @Questions.db.ObjectId().toString()
          dateCreated: new Date()
          gameId: result[0]._id
          period: result[0].period
          playId:  details.playdetails.playId
          details:  details.multiplierArguments
          extendedDetails: details
          type: "play"
          active: true
          commercial: false
          que: @generateQuestionTitle details
          options: options
          usersAnswered: []

  generateQuestionTitle: (play) ->
    if play.nextPlay.playType is "PAT"
      que = "Point After Attempt"
    else if play.nextPlay.playType is "Kickoff"
      que = "Kickoff"
    else if play.playdetails.isFirstDown
      downGrammer = @downGrammer 1
      que =  downGrammer + " & " + play.distance.yardsToFirstDown + " Yards"
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
