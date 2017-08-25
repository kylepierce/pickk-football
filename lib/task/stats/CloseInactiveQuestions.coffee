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
    @getPlayDetails = new GetPlayDetails dependencies
    @createPlayQuestions = new CreatePlayQuestions dependencies

  execute: (eventId, teams) ->
    Promise.bind @
      .then -> @Games.find({id: eventId})
      .then (game) -> @Questions.find({gameId: game[0]._id, type: "play", active: true});
      .map (question) -> @closeQuestion question, teams

  closeQuestion: (question, teams) ->
    Promise.bind @
      .then -> @getSinglePlayResult question
      .then (playResult) -> @getCorrectOptionNumber question, playResult, teams
      # .then (optionNumber) -> @updateQuestionAndAnswers question._id, optionNumber
      # .map (answer) -> @awardUsers answer, outcome

  getSinglePlayResult: (question) ->
    Promise.bind @
      .then -> @getGame question.gameId
      .then (game) -> _.flatten game[0].pbp, 'playId'
      .then (list) -> @getPlayResult list, question.playId

  getPlayResult: (list, playId) ->
    # The playId comes from the play that happened before the question was created.
    # Unfortunately there is not other way to associate that I am aware of.
    Promise.bind @
      .then ->_.indexOf list,  _.find list, (play) -> return play.playId is playId # Find the index of previous play in pbp array
      .then (index) -> list[index + 1] # Then find the next item in the pbp array. Which should be this question's result.

  getCorrectOptionNumber: (question, result, teams) ->
    playDetails = @getPlayDetails.execute result, teams
    Promise.bind @
      .then -> _.map question.options, (option) -> return option['title']
      .then (titles) -> @getPlayOptionTitle titles, playDetails
      .then (title) -> console.log question.que, ">>>", title
      # .then (optionTitle) -> console.log optionTitle
        # @getPlayOptionNumber optionTitle

  getPlayOptionTitle: (titles, play) ->
    Promise.bind @
      # .then -> console.log "Possible Question Outcomes: \n", titles, "\n", "Play Result: \n", play, "\n \n"
      .then -> answers = [
        title: "Run",
        requirements:
          typeId: [3, 4]
      ,
        title: "Pass",
        requirements:
          typeId: [1, 2, 9, 19, 23]
      ,
        title: "Interception",
        requirements:
          typeId: [9, 19],
          teamChange: true
      ,
        title: "Fumble",
        requirements:
          typeId: [14, 15, 16],
          teamChange: true
      ,
        title: "Pick Six",
        requirements:
          typeId: [19],
          teamChange: true
      ,
        title: "Unable to Covert First Down",
        requirements:
          isFirstDown: false
      ,
        title: "Convert to First Down",
        requirements:
          isFirstDown: false
      ,
        title: "Touchdown",
        requirements:
          scoreType: "Touchdown"
      ,
        title: "Kick Good!,"
        requirements:
          scoreType: ["Field Goal", "PAT"]
      ,
        title: "Two Point Good",
        requirements:
          scoreType: "Two Points"
      ,
        title: "Safety",
        requirements:
          scoreType: "Two Points",
          teamChange: true
      ,
        title: "Missed Kick",
        requirements:
          playType: "Field Goal"
      ,
        title: "Blocked Kick",
        requirements:
           playType: ["Field Goal", "Punt"]
      ,
        title: "Failed Onside",
        requirements:
          playType: ["Kickoff"],
          teamChange: true
      ,
        title: "Successful Onside",
        requirements:
          playType: ["Kickoff"],
          teamChange: false
      ,
        title: "Blocked Punt",
        requirements:
          playType: ["Punt"],
          typeId: [18]
      ,
      #   title: "Fake Kick No Score"
      #,   requirements:
      # ,
        title: "Two Point No Good",
        requirements:
          typeId: [53, 54, 55]
      ,
        title: "Fair Catch/No Return",
        requirements:
           playType: ["Punt"],
           typeId: [21]
      ,
        title: "Touchback/No Return",
        requirements:
          playType: ["Kickoff"],
          typeId: [21]
      ,
        title: "Neg to 25 Yard Return",
        requirements:
          playType: ["Kickoff"]
          # yards: <25
      ,
        title: "Neg to 20 Yard Return",
        requirements:
          playType: ["Punt"]
          # yards: <20
      ,
        title: "21-40 Yard Return",
        requirements:
          playType: ["Punt"]
          # yards: >= 21 && yards <= 40
      ,
        title: "26+ Return",
        requirements:
          playType: ["Punt"]
          # yards: >= 26
      ,
        title: "26-45 Return",
        requirements:
          playType: ["Punt"]
          # yards:
      ,
        title: "46+,"
        requirements:
          playType: ["Punt"]
          # yards: > 21 || < 40
      ]

      .then (answers) ->
        correct = []
        _.each titles, (title) -> # Look at each optionTitle
          _.find answers, (answer) -> # Find answer with matching title
            if answer['title'] is title
              keys = _.allKeys answer.requirements

              _.each keys, (key) ->
                answerValue = answer.requirements[key]
                playValue = play.playDetails[key]

                if _.isArray answerValue
                  if (answerValue.indexOf playValue) > -1
                    # console.log answer.title
                    # return true
                    correct.push(answer.title)

                else if answerValue is playValue
                  # console.log answer.title
                  # return true
                  correct.push(answer.title)
              # console.log outcome
        return correct

                # if answer[key] is play.playDetails[key]
                #   console.log answer
            # Does the playDetails match the requirements
            # if it does add it to the correct answer array.

      # drive
			# "Punt",
      # "Field Goal",
      # "Turnover",
      # "Touchdown",
      # "Turnover on Downs",
      # "Safety"

  penalty: (typeId) ->
    if typeId is 10 || typeId is 11
      console.log "penalty -- Delete Last Question"
      return "Penalty"

  kickoffQuestion: (titles, play) ->
    list = [5, 6, 25, 41, 43]
    if play.playDetails.type is "Kickoff"
      console.log "Kickoff"
      if play.playDetails.teamChange is false
        return "Fumble"
        # "Successful Onside"
      if play.playDetails.scoreType
        return "Touchdown"
      # if no return
      #   "Touchback/No Return",
      # if yards
        # "Neg to 25 Yard Return",
        # "26-45 Return",
        # "26+ Return",
        # "46+",
        # "Failed Onside",

  pointAfterQuestion: (titles, play) ->
    list = [22, 47, 49, 53, 54, 55, 56]
    if play.playDetails.type is "PAT"
      console.log "PAT"
    # "Kick Good!",
    # "Fake Kick No Score",
    # "Blocked Kick",
    # "Missed Kick",
    # "Two Point Good",
    # "Two Point No Good"

  puntQuestion: (titles, play) ->
    list = [7, 8, 18, 24, 71]
    if play.playDetails.type is "Punt"
      console.log "Punt"
    # Punt - Return yards
    # When play type is 7
    # Down is 4
    # When kickType exists
    # "Fair Catch/No Return", - KickType: 6, 9, 10, 11, 24,
    # "Neg to 20 Yard Return", "21-40 Yard Return", - result.distance
    # "Blocked Punt", - KickType: 13
    # "Fumble", - playTypeId: 14, KickType: 12
    # "Touchdown" -

  fieldGoalQuestion: (titles, play) ->
    list = [17, 35, 36, 42, 50]
    if play.playDetails.type is "Field Goal"
      console.log "Field Goal"
    # Field goal - Successful?
    # if down is 4
    # "Kick Good!",
    # "Run",
    # "Pass",
    # "Fumble",
    # "Missed Kick",
    # "Blocked Kick"

  thirdDownQuestion: (titles, play) ->
    # if result.down is 3
    if play.previous.down is 3
      console.log "Third Down"
    #   # if distance from endzone is less then 10
    #   # else
      if play.playDetails.isFirstDown
        return "Convert to First Down"
      else if !play.playDetails.isFirstDown
        return "Unable to Covert First Down"
      if play.playDetails.teamChange
        console.log "Turnover"
        return
        # "Interception",
        # "Fumble",
        # if playDetails.scoreType
          # "Pick Six",
      if play.playDetails.coreType
        return "Touchdown"

  normalQuestion: (titles, play) ->
    if play.previous.down is 1 || play.previous.down is 2
      console.log "Normal Play"
      if play.playDetails.playType is "Run"
        return "Run"
      else if play.playDetails.playType is "Pass"
        return "Pass"
      if play.playDetails.teamChange
        # "Interception",
        # "Fumble",
        return "Turnover"
        # if scoreType
          # "Pick Six",
      if play.playDetails.scoreType
        return "Touchdown"

  getPlayOptionNumber: (optionTitle) ->
    console.log "Play Outcome", optionTitle
    # Promise.bind @
      # .then -> _.invert _.mapObject question['options'], (option) -> option['title']
      # .then (options) -> console.log "-------- \n", "Play Outcome:", options[optionTitle], "\n", outcome, "\n", options
      # .then (options) -> options[outcome]

  updateQuestionAndAnswers: (questionId, outcome) ->
    Promise.bind @
      .then -> @Questions.update {_id: questionId}, $set: {active: false, outcome: outcome, lastUpdated: new Date()} # Close and add outcome string
      .then -> @Answers.update {questionId: questionId, answered: {$ne: outcome}}, {$set: {outcome: "lose"}}, {multi: true} # Losers
      .then -> @Answers.find {questionId: questionId, answered: outcome} # Find the winners

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

  getGame: (gameId) ->
    Promise.bind @
      .then -> @Games.find {_id: gameId}
