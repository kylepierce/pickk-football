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
CommercialQuestions = require "./CommericalQuestions"
DriveQuestions = require "./DriveQuestions"

module.exports = class extends Task
  constructor: (dependencies) ->
    super

    Match.check dependencies, Match.ObjectIncluding
      mongodb: Match.Any

    @logger = @dependencies.logger
    @Games = dependencies.mongodb.collection("games")
    @QuestionTemplate = dependencies.mongodb.collection("questionTemplate")
    @Questions = dependencies.mongodb.collection("questions")
    @Teams = dependencies.mongodb.collection("teams")
    @closeInactiveQuestions = new CloseInactiveQuestions dependencies
    @createPlayQuestions = new CreatePlayQuestions dependencies
    @endOfGame = new EndOfGame dependencies
    @getPlayDetails = new GetPlayDetails dependencies
    @commercialQuestions = new CommercialQuestions dependencies
    @driveQuestions = new DriveQuestions dependencies

  execute: (old, update) ->
    Promise.bind @
      .then -> @Games.findOne({eventId: update.eventId})
      .then (result) -> @other old, update, result._id

  other: (old, update, gameId) ->
    @checkCommercialStatus gameId

    if old.pbp
      oldPlays = old.pbp.length
      newPlays = update.pbp.length
    if @isNewPlay newPlays, oldPlays
      gameTeams = update.teams
      @updatedPbp = update.pbp
      previousPlay = _.last @updatedPbp
      play = @getPlayDetails.execute previousPlay, gameTeams

      Promise.bind @
        # .then -> @endOfDrive update.pbp, old.pbp
        .then -> @endCommercialBreak gameId
        .then -> @closeInactiveQuestions.execute gameId, @updatedPbp, gameTeams
        .then -> @processWithPreviousDetails gameId, play, gameTeams

  processWithPreviousDetails: (gameId, play, gameTeams) ->
    all = ["drive", "period", "half", "game"]

    Promise.bind @
      .then -> @createPlayQuestions.execute gameId, play, gameTeams
      .then (question) -> @updateGameCard gameId, play, question
      .then -> @commercialQuestions.resolveAll gameId, play, all
      .then -> @startCommercialBreak gameId, play, gameTeams

  isNewPlay: (newLength, oldLength) ->
    if newLength > oldLength
      return true

  createCommercialQuestions: (gameId, previous) ->

  endOfDrive: (update, old) ->
    newPlay = _.last update
    oldPlay = _.last old
    if newPlay.driveId > oldPlay.driveId
      console.log "New Drive!"

  startCommercialBreak: (gameId, previous, gameTeams) ->
    list = ["Punt", "PAT", "Field Goal", "Turnover", "Turnover on Downs", "Safety"]
    if (list.indexOf(previous.playDetails.type) > -1)
      correctTeam = @correctTeam previous.playDetails.teamId, gameTeams
      drive = parseInt(previous.playDetails.driveId) + 1

      Promise.bind @
        .then -> @commercialQuestions.resolveAll gameId, previous, ["drive"], "drive"
        .then -> @getCommercialBreakQuestion "NFL", "drive", 2
        .map (templateId) -> @commercialQuestions.create gameId, templateId
        .then -> @driveQuestions.resolve gameId, @updatedPbp, gameTeams
        .then -> @driveQuestions.create gameId, correctTeam, drive, gameTeams
        .then -> @Games.update({_id: gameId}, {$set: {commercial: true, commercialTime: new Date}})

  updateGameCard: (gameId, play, question) ->
    if play.period is 1 then quarter = "1st"
    if play.period is 2 then quarter = "2nd"
    if play.period is 3 then quarter = "3rd"
    if play.period is 4 then quarter = "4th"
    if play.period > 4 then quarter = "Overtime"
    yards = question.que.indexOf("Yards")
    clean = question.que.substr 0, yards
    if yards is -1
      clean = question.que
    location = (_.last @updatedPbp).endYardLine
    @Games.update({_id: gameId}, {$set: {
      location: location
      downAndDistance: clean
      time: play.time
      quarter: quarter
      distanceToTouchdown: play.yardsToTouchdown
      distanceToFirstDown: play.distance.yardsToFirstDown
      whoHasBall: play.playDetails.endTeamId
    }})

  getCommercialBreakQuestion: (sport, length, number) ->
    query = {sport: sport, length: length}
    Promise.bind @
      .then -> @QuestionTemplate.count(query)
      .then (count) -> return Math.floor(Math.random() * count)
      .then (randomNum) -> @QuestionTemplate.find(query).limit(number).skip(randomNum);
      .map (template) -> return template._id

  correctTeam: (lastTeam, teams) ->
    index = _.findIndex(teams, {teamId: lastTeam})

    if index is 0
      correctTeam = teams[1]
    else if index is 1
      correctTeam = teams[0]

    return correctTeam

  checkCommercialStatus: (gameId) ->
    newTime =  moment(new Date).toISOString()
    commercialBreak = @dependencies.settings['common']['commercialTime']
    Promise.bind @
      .then -> @Games.find({_id: gameId})
      .then (game) ->
        if game.commercialTime
          oldTime = moment(game.commercialTime).add(commercialBreak, 'seconds').toISOString()
          if newTime > oldTime
            Promise.bind @
              .then -> @endCommercialBreak gameId

  # gameInProgress: (eventId) ->
  #   Promise.bind @
  #     .then -> @getGame eventId
  #     .then (game) ->
  #       if game.commercial is true
  #         console.log "Game has resumed already!!"
  #         @endCommercialBreak eventId

  endCommercialBreak: (gameId) ->
    Promise.bind @
      .then -> @Games.update({_id: gameId}, {$set: {commercial: false}, $unset: {commercialTime: 1}})
          # .then -> @Questions.update({gameId: game._id, period: game.period, active: true, commercial: false}, {$set: {dateCreated: new Date()}})
          # .then (result) -> console.log "Reactivated:", result.que
