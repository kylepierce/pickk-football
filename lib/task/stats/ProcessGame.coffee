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
    @Answers = dependencies.mongodb.collection("answers")
    @GamePlayed = dependencies.mongodb.collection("gamePlayed")
    @Users = dependencies.mongodb.collection("users")
    @Notifications = dependencies.mongodb.collection("notifications")
    @gameParser = new GameParser dependencies
    @endOfGame = new EndOfGame dependencies

  execute: (old, update) ->
    if old.pbp
      oldPlays =  old.pbp.length
      newPlays = update.pbp.length
    if @isNewPlay newPlays, oldPlays
      previousPlay = (_.last update.pbp)
      previousPlayDetails = @playDetails previousPlay
      console.log "Previous:", previousPlayDetails

      Promise.bind @
        .then -> @nextPlayDetails previousPlayDetails
        .then (result) -> @createLiveQuestion update.eventId, result

  playDetails: (play) ->
    details =
      isFirstDown: @reachedFirstDown play.yards, play.distance
      type: @lastPlayType play.playType.playTypeId
      teamChange: @hasBallChangedTeams play.startPossession.teamId, play.endPossession.teamId
      scoreType: @hasScoreChange play.awayScoreBefore, play.awayScoreAfter, play.homeScoreBefore, play.homeScoreAfter
      location: @quantifyLocation play.endYardLine
      down: play.down
      distance: play.distance
      yards: play.yards
    return details

  reachedFirstDown: (yards, distance) ->
    if yards > distance
      return true
    else
      return false

  nextPlayDetails: (previous) ->
    Promise.bind @
      .then -> @nextPlayType previous
      .then (result) -> @getDownAndDistance result, previous
      .then (result) -> return result # down, area, yards, style

  isNewPlay: (newLength, oldLength) ->
    if newLength > oldLength
      return true

  nextPlayType: (previous) ->
    switchTeams = ["kickoff", "punt", "turnover", "turnover on downs"]
    kickoffType = ["pat", "field goal"]
    switchT = switchTeams.indexOf(previous.type)
    kickoffT = kickoffType.indexOf(previous.type)
    console.log switchT, kickoffT
    if switchT > 0
      nextPlayType = "First Down"
    else if previous.isFirstDown
      nextPlayType = "First Down"
    else if kickoffT > 0
      nextPlayType = "Kickoff"
    else
      nextPlayType = "Normal"
    return nextPlayType

  hasBallChangedTeams: (startTeam, endTeam) ->
    if startTeam isnt endTeam
      return true
    else
      return false

  getDownAndDistance: (nextPlayType, previous) ->
    if nextPlayType is "Kickoff"
      down = 6
      area = 2
      yards = 1
      style = 2
      distance = null
    else if nextPlayType is "First Down"
      down = 1
      distance = 10
      yards = 3
      area = 3
      style = 2
    else
      down = parseInt(previous.down) + 1
      distance = previous.distance - previous.yards
      yards = 3
      area = 3
      style =2

    multiplierArguments =
      nextPlayType: nextPlayType
      down: down
      distance: distance
      yards: yards
      area: area
      style: style

    return multiplierArguments

  hasScoreChange: (awayScoreBefore, awayScoreAfter, homeScoreBefore, homeScoreAfter) ->
    awayScoreChange = @teamScore awayScoreAfter, awayScoreBefore
    homeScoreChange = @teamScore homeScoreAfter, homeScoreBefore
    if awayScoreChange
      score = awayScoreChange
    else if homeScoreChange
      score = homeScoreChange
    else
      score = false
    return score

  quantifyLocation: (location) ->
    return location

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

  lastPlayType: (playTypeId) ->
    playType = [
      title: "Pass",
      outcomes: [1, 2, 9, 19, 23]
    ,
      title: "Run",
      outcomes: [3, 4]
    ,
      title: "Fumble",
      outcomes: [14, 15, 16]
    ,
      title: "Turnover",
      outcomes: [9, 19, 16]
    ,
      title: "Timeout",
      outcomes: [13, 29, 57, 58]
    ,
      title: "Punt",
      outcomes: [7, 8]
    ,
      title: "Kickoff",
      outcomes: [5, 6]
    ,
      title: "Penalty",
      outcomes: [10, 11] # 10 is against offense -- 11 is against defense
    ,
      title: "Field Goal",
      outcomes: [17, 42]
    ,
      title: "Turnover on Downs",
      outcomes: [18, 35, 36]
    ]

    for item in playType
      if (item['outcomes'].indexOf playTypeId) > -1
        type = item['title']
        return type

  teamScore: (after, before) ->
    if after > before
      if after - before is 1
        return "PAT"
      if after - before is 2
        return "Safety"
      if after - before is 3
        return "Field Goal"
      if after - before is 6
        return "Touchdown"
    else
      return false

  createLiveQuestion: (eventId, details) ->
    if details.nextPlayType isnt "Normal" && details.nextPlayType isnt "First Down"
      que = details.nextPlayType
    else
      downGrammer = @downGrammer details.down
      que =  downGrammer + " & " + details.distance

    @logger.verbose details, "Que:", que

    Promise.bind @
      .then ->
        @Multipliers.find {
          "down": details.down,
          "area": details.area,
          "yards": details.yards,
          "style": 2
        }
      .then (result) -> @parseOptions result[0].options
      .then (result) -> @insertLiveQuestion eventId, que, result

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

  insertLiveQuestion: (eventId, que, options) ->
    Promise.bind @
      .then ->@Games.find {eventId: eventId}
      .then (result) ->
        @Questions.insert
          _id: @Questions.db.ObjectId().toString()
          dateCreated: new Date()
          gameId: result[0]._id
          period: result[0].period
          type: "play"
          active: true
          commercial: false
          que: que
          options: options
          usersAnswered: []

  # Promise.bind @
  #   .then (parms) ->
  #   .return true
  #   .catch (error) =>
  #     @logger.error error.message, _.extend({stack: error.stack}, error.details)
