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

      Promise.bind @
        .then -> @closeInactiveQuestions update.id, previousPlayDetails
        .then -> @nextPlayDetails previousPlayDetails
        .then (result) -> @createLiveQuestion update.eventId, result

  playDetails: (play) ->
    details =
      playId: play.playId
      isFirstDown: @reachedFirstDown play.yards, play.distance
      type: @findPlayType play.playType.playTypeId
      teamChange: @hasBallChangedTeams play.startPossession.teamId, play.endPossession.teamId
      scoreType: @hasScoreChange play.awayScoreBefore, play.awayScoreAfter, play.homeScoreBefore, play.homeScoreAfter
      distanceToGoal: @distanceToGoal play.startPossession.teamId, play.endYardLine
      location: @quantifyLocation play.startPossession.teamId, play.endYardLine
      isInRedZone: @isRedZone play.startPossession.teamId, play.endYardLine, play.distance
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
    switchTeams = ["Kickoff", "Punt", "Turnover", "Turnover on Downs"]
    kickoffType = ["Pat", "Field goal"]
    switchT = switchTeams.indexOf(previous.type)
    kickoffT = kickoffType.indexOf(previous.type)
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
      playId: previous.playId
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

  quantifyLocation: (teamIdWithBall, location) ->
    distance = @distanceToGoal teamIdWithBall, location
    # 1 0-10
    # 2 11-30
    # 3 30-60
    # 4 60-80
    # 5 80-90
    # 6 90-100
    return location

  distanceToGoal: (teamIdWithBall, location) ->
    # Use teamIdWithBall shortcode
    # See if they are on their side or the other teams
    # Example: TeamA is going to TeamB's 0 yard line. Or TMB0
    # if on the their side add 50 yards
    # TMA21 is 71 yards away
    # value = 71
    # if on their opponents side its the number
    # TMB32 is 32 yards from goal
    # value is 32

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

  findPlayType: (playTypeId) ->
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

    Promise.bind @
      .then ->
        @Multipliers.find {
          "down": details.down,
          "area": details.area,
          "yards": details.yards,
          "style": 2
        }
      .then (result) -> @parseOptions result[0].options
      .then (result) -> @insertLiveQuestion eventId, que, result, details

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

  insertLiveQuestion: (eventId, que, options, details) ->
    Promise.bind @
      .then ->@Games.find {eventId: eventId}
      .then (result) ->
        @Questions.insert
          _id: @Questions.db.ObjectId().toString()
          dateCreated: new Date()
          gameId: result[0]._id
          period: result[0].period
          playId: details.playId
          type: "play"
          active: true
          commercial: false
          que: que
          options: options
          usersAnswered: []

  closeInactiveQuestions: (eventId) ->
    Promise.bind @
      .then -> @Games.find({id: eventId})
      .then (game) -> @Questions.find({gameId: game[0]._id, type: "play", active: true});
      .map (questions) -> @closeQuestion questions

  closeQuestion: (question) ->
    Promise.bind @
      .then -> @findPlayResult question
      .then (result) -> processQuestion question, result
      # .then (optionNumber) -> @updateQuestion question._id, optionNumber

  findPlayResult: (question) ->
    Promise.bind @
      .then -> @findGame question.gameId
      .then (game) -> @findPlay game[0], question.playId

  processQuestion: (question, result) ->
    Promise.bind @
      .then (result) -> @findPlayStyle question, result
      # Return the title
      .then (playType) -> @getCorrectOption question, outcome
      # Return the option number

  updateQuestion: (questionId, outcome) ->
    Promise.bind @
      .then -> @Questions.update {_id: questionId}, $set: {active: false, outcome: outcome, lastUpdated: new Date()} # Close and add outcome string
      .then -> @Answers.update {questionId: questionId, answered: {$ne: outcome}}, {$set: {outcome: "lose"}}, {multi: true} # Losers
      .then -> @Answers.find {questionId: questionId, answered: outcome} # Find the winners
      .map (answer) -> @awardUsers answer, outcome

  findPlayStyle: (question, result) ->
    playDetails = @playDetails result
    # details =
    #   playId:
    #   isFirstDown:
    #   type:
    #   teamChange:
    #   scoreType:
    #   location:
    #   down:
    #   distance:
    #   yards:
    Promise.bind @
      .then -> @kickoffQuestion question, result, playDetails
      .then -> @pointAfterQuestion question, result, playDetails
      .then -> @puntQuestion question, result, playDetails
      .then -> @fieldGoalQuestion question, result, playDetails
      .then -> @thirdDownQuestion question, result, playDetails
      .then -> @normalQuestion question, result, playDetails
      # Return the title of the play

  kickoffQuestion: (question, result, playDetails) ->
    list = [5, 6, 25, 41, 43]
    if (list.indexOf(result.playType.playTypeId) > 0)
      # if teamChange is false
        # "Fumble",
        # "Successful Onside",
      # if scoreType
        # "Touchdown"
      # if no return
        # "Touchback/No Return",
      # if yards
        # "Neg to 25 Yard Return",
        # "26-45 Return",
        # "26+ Return",
        # "46+",
        # "Failed Onside",

  pointAfterQuestion: (question, result, playDetails) ->
    list = [22, 47, 49, 53, 54, 55, 56]
    if playDetails.scoreType is "PAT"
    # "Kick Good!",
    # "Fake Kick No Score",
    # "Blocked Kick",
    # "Missed Kick",
    # "Two Point Good",
    # "Two Point No Good"

  puntQuestion: (question, result, playDetails) ->
    list = [7, 8, 18, 24, 71]
    # Punt - Return yards
    # When play type is 7
    # Down is 4
    # When kickType exists
    # "Fair Catch/No Return", - KickType: 6, 9, 10, 11, 24,
    # "Neg to 20 Yard Return", "21-40 Yard Return", - result.distance
    # "Blocked Punt", - KickType: 13
    # "Fumble", - playTypeId: 14, KickType: 12
    # "Touchdown" -

  fieldGoalQuestion: (question, result, playDetails) ->
    list = [17, 35, 36, 42, 50]
    # Field goal - Successful?
    if down is 4
    # "Kick Good!",
    # "Run",
    # "Pass",
    # "Fumble",
    # "Missed Kick",
    # "Blocked Kick"

  thirdDownQuestion: (question, result, playDetails) ->
    if result.down is 3
      # if distance from endzone is less then 10
      # else
      if playDetails.isFirstDown
        return "Convert to First Down"
      if !playDetails.isFirstDown
        return "Unable to Covert First Down",
      if teamChange
        # "Interception",
        # "Fumble",
        if scoreType
          # "Pick Six",
      if scoreType
        # "Touchdown"

  normalQuestion: (question, result, playDetails) ->
    if result.down is 1 || result.down is 2
      # if playTypeId is "Run",
      # if playTypeId is "Pass",
      if teamChange
        # "Interception",
        # "Fumble",
        # "Turnover",
        if scoreType
          # "Pick Six",
      if scoreType
        # "Touchdown"

  isRedZone: (teamIdWithBall, location, yards) ->
    distance = @distanceToGoal teamIdWithBall, location
    if distance > 20
      return true

  getCorrectOption: (question, outcome) ->
    Promise.bind @
      .then -> _.invert _.mapObject question['options'], (option) -> option['title']
      .then (options) -> console.log "-------- \n", "Play Outcome:", options[outcome], "\n", outcome, "\n", options,
      # .then (options) -> options[outcome]
      # .then (result) -> console.log result

  findPlay: (game, playId) ->
    # The playId comes from the play that happened before the question was created.
    # Unfortunately there is not other way to associate that I am aware of.
    Promise.bind @
      # Find the previous play index in pbp array
      .then -> @specificEventIndex game, playId
      # Then find the next item in the pbp array. Which should be this question's result.
      .then (index) -> @specificEventResult game, index

  specificEventIndex: (game, playId) ->
    Promise.bind @
      .then -> @getPlays game # Filter out plays that are not relevant.
      .then (list) -> _.indexOf(list, playId)

  specificEventResult: (game, index) ->
    Promise.bind @
      .then -> @getPlays game # Filter out plays that are not relevant.
      .then (list) -> list[index + 1]

  findGame: (gameId) ->
    Promise.bind @
      .then -> @Games.find {_id: gameId}

  getPlays: (game) ->
    Promise.bind @
      .then -> _.flatten game.pbp, 'playId'
      .then (list) -> _.filter list, @ignoreList

  ignoreList: (single) ->
    list = [10, 11, 13, 29, 57, 58]
    if (list.indexOf(single) is -1)
      return true

  awardUsers: (answer, outcomeOption) ->
    reward = Math.floor answer['wager'] * answer['multiplier']
    Promise.bind @
      .then -> @Answers.update {_id: answer._id}, {$set: {outcome: "win"}} #
      .then -> @GamePlayed.update {userId: answer['userId'], gameId: answer.gameId}, {$inc: {coins: reward}}
      .tap -> @logger.verbose "Awarding correct users!"
      .then ->
        @Notifications.insert
          _id: @Notifications.db.ObjectId().toString()
          dateCreated: new Date()
          question: answer.questionId
          userId: answer['userId']
          gameId: answer.gameId
          type: "coins"
          value: reward
          read: false
          message: "Nice Pickk! You got #{reward} Coins!"
          sharable: false
          shareMessage: ""
