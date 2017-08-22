createDependencies = require "../../../../helper/dependencies"
settings = (require "../../../../helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")
Promise = require "bluebird"
moment = require "moment"
_ = require "underscore"
ImportGames = require "../../../../lib/task/stats/ImportGames"
loadFixtures = require "../../../../helper/loadFixtures"
ProcessGame = require "../../../../lib/task/stats/ProcessGame"
statsGame = require "../../../../lib/model/Game"
db = require 'mocha-mongodb'
# TwoActiveGamesFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/TwoActiveGames.json"
# QuestionsFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/Questions.json"
# ActualQuestionsFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActualQuestions.json"
# NonActualQuestionsFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/NonActualQuestions.json"
# NonActualPitchQuestionsFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/NonActualPitchQuestions.json"
# ClosedCommercialQuestionFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ClosedCommercialQuestion.json"
# ActiveCommercialQuestionFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveCommercialQuestion.json"
ActiveFullGameFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveFullGame.json"
# ActiveFullGameWithLineUp = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveFullGameWithLineUp.json"
# ActiveGameLineupInningOnly = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveGameLineupInningOnly.json"
# ActiveGameNoInningsFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveGameNoInnings.json"
# ActiveGameNoPlaysFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveGameNoPlays.json"
# ActiveGameEndOfInningFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveGameEndOfInning.json"
# ActiveGameEndOfHalfFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveGameEndOfHalf.json"
# ActiveGameEndOfPlayFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveGameEndOfPlay.json"
# ActiveGameMiddleOfPlayFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveGameMiddleOfPlay.json"
# UnhandledFinishedGameFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/UnhandledFinishedGame.json"
# GamePlayedFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/GamePlayed.json"
# TeamsFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/Teams.json"
# PlayersFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/Players.json"
# AtBatsFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/AtBats.json"
# ActiveAtBatFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/ActiveAtBat.json"
# UsersFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/Users.json"
# AnswersFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/Answers.json"
# CommercialAnswersFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/CommercialAnswers.json"
# WrongAnswersFixtures = require "#{process.env.ROOT_DIR}/test/fixtures/task/stats/processGame/collection/WrongAnswers.json"

describe "Process imported games and question management", ->
  @timeout(5000)
  dependencies = createDependencies settings, "PickkImport"
  @mongodb = dependencies.mongodb

  processGame = undefined

  Games = @mongodb.collection("games")
  Teams = @mongodb.collection("teams")
  Questions = @mongodb.collection("questions")
  Users = @mongodb.collection("users")
  Answers = @mongodb.collection("answers")
  GamePlayed = @mongodb.collection("gamePlayed")
  Notifications = @mongodb.collection("notifications")

  activeGameId = 1744080
  inactiveGameId = "2b0ba18a-41f5-46d7-beb3-1e86b9a4acc0"
  actualActiveQuestionId = "active_question_for_active_game"
  nonActualActiveQuestionId = "active_question_for_inactive_game"

  beforeEach ->
    processGame = new ProcessGame dependencies

    Promise.bind @
      .then ->
        Promise.all [
          Games.remove()
          Teams.remove()
          Questions.remove()
          Users.remove()
          Answers.remove()
          GamePlayed.remove()
          Notifications.remove()
        ]
      .done()

  it 'should create new play question', ->
    Promise.bind @
      .then -> loadFixtures ActiveFullGameFixtures, @mongodb
      .then (result) ->
        should.exist result
      #   question.should.be.an "object"
      #   {eventStatus} = game
      #   should.exist eventStatus
      #   {eventStatusId} = eventStatus
      #   should.exist eventStatusId
      #   eventStatusId.should.be 3
      # .done()

        # {active} = question
        # should.exist active
        # active.should.be.equal true
#
#   it 'should update actual play question', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures ActualQuestionsFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({id: "active_question_for_active_game"})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active, options} = question
#       should.exist active
#       # should be still active
#       active.should.be.equal true
#
#       # check options have been updated
#       should.exist options
#
#   it 'should disable non-actual play question', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures NonActualQuestionsFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({id: "non_actual_question_for_active_game"})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal false
#
#   it 'should create new pitch question', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "abbda8e1-2274-4bf0-931c-691cf8bf24c6", atBatQuestion: {$exists: false}})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active, play, pitch} = question
#       should.exist active
#       active.should.be.equal true
#
#       should.exist play
#       play.should.be.equal 28
#
#       should.exist pitch
#       pitch.should.be.equal 6
#
#   it 'should update actual pitch question with the same play and pitch number', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures ActualQuestionsFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({id: "active_pitch_question_for_active_game"})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active, play, pitch} = question
#
#       should.exist active
#       # should be still active
#       active.should.be.equal true
#
#       should.exist play
#       play.should.be.equal 28
#
#       should.exist pitch
#       pitch.should.be.equal 6
#
#   it 'should create a pitch question if play and pitch number is different', ->
#     game = undefined
#
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures NonActualPitchQuestionsFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (_game) -> game = _game; processGame.execute game
#     .then -> Questions.findOne({id: "active_non_actual_pitch_question_for_active_game"})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active, play, pitch} = question
#
#       should.exist active
#       active.should.be.equal false
#
#       should.exist play
#       play.should.be.equal 28
#
#       should.exist pitch
#       pitch.should.be.equal
#
#     .then -> Questions.findOne({gameId: game._id, active: true, atBatQuestion: {$exists: false}})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {play, pitch} = question
#
#       should.exist play
#       play.should.be.equal 28
#
#       should.exist pitch
#       pitch.should.be.equal 6
#
#   it 'should disable non-actual pitch question', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures NonActualQuestionsFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({id: "non_actual_pitch_question_for_active_game"})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       # should be still active
#       active.should.be.equal false
#
#   it 'should reward the user for right answer on pitch question', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures NonActualPitchQuestionsFixtures, mongodb
#     .then -> loadFixtures UsersFixtures, mongodb
#     .then -> loadFixtures GamePlayedFixtures, mongodb
#     .then -> loadFixtures AnswersFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> GamePlayed.findOne({userId: "Charlie"})
#     .then (gamePlayed) ->
#       should.exist gamePlayed
#       {coins} = gamePlayed
#       should.exist coins
#       coins.should.be.equal 13435
#     .then -> Notifications.find({userId: "Charlie"})
#     .then (notifications) ->
#       should.exist notifications
#       notifications.should.be.an "array"
#       notifications.length.should.be.equal 1
#
#   it 'should reward the user for right answer on play question', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures NonActualQuestionsFixtures, mongodb
#     .then -> loadFixtures UsersFixtures, mongodb
#     .then -> loadFixtures GamePlayedFixtures, mongodb
#     .then -> loadFixtures AnswersFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> GamePlayed.findOne({userId: "Charlie"})
#     .then (gamePlayed) ->
#       should.exist gamePlayed
#       {coins} = gamePlayed
#       should.exist coins
#       coins.should.be.equal 13735
#     .then -> Notifications.find({userId: "Charlie"})
#     .then (notifications) ->
#       should.exist notifications
#       notifications.should.be.an "array"
#       notifications.length.should.be.equal 1
#
#   it 'shouldn\'t reward the user for wrong answer on pitch question', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures NonActualQuestionsFixtures, mongodb
#     .then -> loadFixtures UsersFixtures, mongodb
#     .then -> loadFixtures GamePlayedFixtures, mongodb
#     .then -> loadFixtures WrongAnswersFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> GamePlayed.findOne({userId: "Charlie"})
#     .then (gamePlayed) ->
#       should.exist gamePlayed
#       {coins} = gamePlayed
#       should.exist coins
#       coins.should.be.equal 13000
#
#   it 'shouldn\'t reward the user for wrong answer on play question', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures NonActualQuestionsFixtures, mongodb
#     .then -> loadFixtures UsersFixtures, mongodb
#     .then -> loadFixtures GamePlayedFixtures, mongodb
#     .then -> loadFixtures WrongAnswersFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> GamePlayed.findOne({userId: "Charlie"})
#     .then (gamePlayed) ->
#       should.exist gamePlayed
#       {coins} = gamePlayed
#       should.exist coins
#       coins.should.be.equal 13000
#
#   it 'should works correctly when no innings are present', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameNoInningsFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.count()
#     .then (result) ->
#       should.exist result
#       result.should.be.equal 0
#
#   it 'should works correctly when no plays are present', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameNoPlaysFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "92500d32-2314-4c7c-91c5-110f95229f9a", atBatQuestion: {$exists: false}})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "92500d32-2314-4c7c-91c5-110f95229f9a", atBatQuestion: true})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#
#   it 'should works correctly when a half is finished', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfHalfFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "1a0bef4b-f97b-453d-80ed-5fde2c80acc8", atBatQuestion: {$exists: false}})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "1a0bef4b-f97b-453d-80ed-5fde2c80acc8", atBatQuestion: true})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#
#   it 'should works correctly when an inning is finished', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfInningFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "3cfaa9a7-8dea-4590-8ea5-c8e1b51232cf", atBatQuestion: {$exists: false}})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "3cfaa9a7-8dea-4590-8ea5-c8e1b51232cf", atBatQuestion: true})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#
#   it 'should works correctly when a play is finished', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfPlayFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "6ac6fa53-ea9b-467d-87aa-6429a6bcb90c", atBatQuestion: {$exists: false}})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "6ac6fa53-ea9b-467d-87aa-6429a6bcb90c", atBatQuestion: true})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#
#   it 'should works correctly when a play is in progress', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameMiddleOfPlayFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "c401dbb6-2208-45f4-9947-db11881daf4f", atBatQuestion: {$exists: false}})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#     .then -> Questions.findOne({game_id: activeGameId, player_id: "c401dbb6-2208-45f4-9947-db11881daf4f", atBatQuestion: true})
#     .then (question) ->
#       should.exist question
#       question.should.be.an "object"
#
#       {active} = question
#       should.exist active
#       active.should.be.equal true
#
#   it 'should create atBat for active batter', ->
#     game = undefined
#
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfPlayFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (_game) -> game = _game; processGame.execute game
#     .then -> AtBats.find()
#     .then (bats) ->
#       should.exist bats
#       bats.should.be.an "array"
#       bats.length.should.equal 1
#
#       bat = bats[0]
#       should.exist bat
#       bat.should.be.an "object"
#
#       {active, playerId, gameId, ballCount, strikeCount} = bat
#
#       should.exist active
#       active.should.equal true
#
#       should.exist playerId
#       playerId.should.equal "6ac6fa53-ea9b-467d-87aa-6429a6bcb90c"
#
#       should.exist gameId
#       gameId.toString().should.equal game._id.toString()
#
#       should.exist ballCount
#       ballCount.should.equal 0
#
#       should.exist strikeCount
#       strikeCount.should.equal 0
#
#   it 'should create new atBat and close another one', ->
#     game = undefined
#
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfPlayFixtures, mongodb
#     .then -> loadFixtures AtBatsFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (_game) -> game = _game; processGame.execute game
#     .then -> AtBats.find()
#     .then (bats) ->
#       should.exist bats
#       bats.should.be.an "array"
#       bats.length.should.equal 2
#
#       activeBat = _.findWhere bats, {active: true}
#       should.exist activeBat
#       activeBat.should.be.an "object"
#
#       {playerId} = activeBat
#
#       should.exist playerId
#       playerId.should.equal "6ac6fa53-ea9b-467d-87aa-6429a6bcb90c"
#
#       inactiveBat = _.findWhere bats, {active: false}
#       should.exist inactiveBat
#
#   it 'should update existing active atBat', ->
#     game = undefined
#
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfPlayFixtures, mongodb
#     .then -> loadFixtures ActiveAtBatFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (_game) -> game = _game; processGame.execute game
#     .then -> AtBats.find()
#     .then (bats) ->
#       should.exist bats
#       bats.should.be.an "array"
#       bats.length.should.equal 1
#
#       bat = bats[0]
#       should.exist bat
#       bat.should.be.an "object"
#
#       {ballCount, strikeCount} = bat
#
#       should.exist ballCount
#       ballCount.should.equal 0
#
#       should.exist strikeCount
#       strikeCount.should.equal 0
#
#   it 'should set commercial break (no timeout)', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfInningFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) ->
#       should.exist game
#
#       {commercial, commercialStartedAt} = game
#       should.exist commercial
#       commercial.should.be.equal true
#
#       should.exist commercialStartedAt
#       duration = moment().diff(commercialStartedAt, 'minute')
#       (duration < dependencies.settings['common']['commercialTime']).should.be.equal true
#
#   it 'shouldn\'t clear commercial startedAt field', ->
#     now = new Date()
#
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfInningFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> Games.update {_id: game._id}, {$set: {commercial: true, commercialStartedAt: now}}
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) ->
#       should.exist game
#
#       {commercial, commercialStartedAt} = game
#       should.exist commercial
#       commercial.should.be.equal true
#
#       should.exist commercialStartedAt
#       commercialStartedAt.getTime().should.be.equal now.getTime()
#
#   it 'should clear commercial flag because of timeout', ->
#     interval = dependencies.settings['common']['commercialTime']
#     now = moment().subtract(interval + 1, 'minutes').toDate()
#
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfInningFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> Games.update {_id: game._id}, {$set: {commercial: true, commercialStartedAt: now}}
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) ->
#       should.exist game
#
#       {commercial, commercialStartedAt} = game
#       should.exist commercial
#       commercial.should.be.equal false
#
#       should.exist commercialStartedAt
#       commercialStartedAt.getTime().should.be.equal now.getTime()
#
#   it 'should clear commercial flag and commercialStartedAt because the game is active', ->
#     interval = dependencies.settings['common']['commercialTime']
#     now = moment().subtract(interval + 1, 'minutes').toDate()
#
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfPlayFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> Games.update {_id: game._id}, {$set: {commercial: true, commercialStartedAt: now}}
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) ->
#       should.exist game
#
#       {commercial, commercialStartedAt} = game
#       should.exist commercial
#       commercial.should.be.equal false
#
#       should.not.exist commercialStartedAt
#
#   it 'should create commercial questions for a team "on pitch" before the first inning', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameLineupInningOnly, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 2
#
#       for question in questions
#         should.exist question
#         {teamId, commercial, inning, binaryChoice, gameId, outcomes} = question
#         teamId.should.be.equal '833a51a9-0d84-410f-bd77-da08c3e5e26e'
#         commercial.should.be.equal true
#         inning.should.be.equal 1
#         binaryChoice.should.be.equal true
#         gameId.should.be.equal activeGameId
#         outcomes.should.be.an "array"
#
#       # questions shouldn't be the same
#       questions[0].que.should.not.be.equal questions[1].que
#
#   it 'should create commercial questions for a team "on pitch" in the next half, end of bottom half', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfInningFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 2
#
#       for question in questions
#         should.exist question
#         {teamId, commercial, inning, binaryChoice, gameId, outcomes} = question
#         teamId.should.be.equal '833a51a9-0d84-410f-bd77-da08c3e5e26e'
#         commercial.should.be.equal true
#         inning.should.be.equal 2
#         binaryChoice.should.be.equal true
#         gameId.should.be.equal activeGameId
#         outcomes.should.be.an "array"
#
#       # questions shouldn't be the same
#       questions[0].que.should.not.be.equal questions[1].que
#
#   it 'should create commercial questions for a team "on pitch" in the next half, end of top half', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfHalfFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 2
#
#       for question in questions
#         should.exist question
#         {teamId, commercial, inning, binaryChoice, gameId, outcomes, active, processed} = question
#         teamId.should.be.equal '47f490cd-2f58-4ef7-9dfd-2ad6ba6c1ae8'
#         commercial.should.be.equal true
#         inning.should.be.equal 2
#         binaryChoice.should.be.equal true
#         gameId.should.be.equal activeGameId
#         outcomes.should.be.an "array"
#         active.should.be.equal true
#         processed.should.be.equal false
#
#       # questions shouldn't be the same
#       questions[0].que.should.not.be.equal questions[1].que
#
#   it 'shouldn\'t create duplicate commercial questions', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfInningFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 2
#
#   it 'shouldn\'t create commercial questions because the game is in progress', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfPlayFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 0
#
#   it 'should close commercial questions because of timeout', ->
#     interval = dependencies.settings['common']['commercialTime']
#     now = moment().subtract(interval + 1, 'minutes').toDate()
#
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfInningFixtures, mongodb
#     .then -> loadFixtures ActiveCommercialQuestionFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> Games.update {_id: game._id}, {$set: {commercial: true, commercialStartedAt: now}}
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 1
#
#       question = questions[0]
#       should.exist question
#       {active, processed} = question
#
#       should.exist active
#       active.should.be.equal false
#
#       should.exist processed
#       processed.should.be.equal false
#
#   it 'should close commercial questions because the game becomes active', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfPlayFixtures, mongodb
#     .then -> loadFixtures ActiveCommercialQuestionFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> Games.update {_id: game._id}, {$set: {commercial: true}}
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 1
#
#       question = questions[0]
#       should.exist question
#       {active, processed} = question
#
#       should.exist active
#       active.should.be.equal false
#
#       should.exist processed
#       processed.should.be.equal false
#
#   it 'should reward the player for the right answer on the commercial questions', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures UsersFixtures, mongodb
#     .then -> loadFixtures GamePlayedFixtures, mongodb
#     .then -> loadFixtures CommercialAnswersFixtures, mongodb
#     .then -> loadFixtures ClosedCommercialQuestionFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> GamePlayed.findOne({userId: "Charlie"})
#     .then (gamePlayed) ->
#       should.exist gamePlayed
#
#       {coins} = gamePlayed
#       should.exist coins
#       coins.should.be.equal 15000
#     .then -> Notifications.find({userId: "Charlie"})
#     .then (notifications) ->
#       should.exist notifications
#       notifications.should.be.an "array"
#       notifications.length.should.be.equal 1
#
#   it 'should not reward the player for the wrong answer on the commercial questions', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures UsersFixtures, mongodb
#     .then -> loadFixtures GamePlayedFixtures, mongodb
#     .then -> loadFixtures CommercialAnswersFixtures, mongodb
#     .then -> loadFixtures ClosedCommercialQuestionFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> GamePlayed.findOne({userId: "James"})
#     .then (gamePlayed) ->
#       should.exist gamePlayed
#
#       {coins} = gamePlayed
#       should.exist coins
#       coins.should.be.equal 6000
#
#   it 'should mark commercial questions as processed with true result', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures ClosedCommercialQuestionFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 1
#
#       question = questions[0]
#       should.exist question
#       {outcome, active, processed} = question
#
#       should.exist outcome
#       outcome.should.be.equal true
#
#       should.exist active
#       active.should.be.equal false
#
#       should.exist processed
#       processed.should.be.equal true
#
#   it 'should mark commercial questions as processed with false result', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures ClosedCommercialQuestionFixtures, mongodb
#     .then -> Questions.findOne({commercial: true})
#     .then (question) -> Questions.update {_id: question._id}, {$set: {outcomes: ["aHR"]}}
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 1
#
#       question = questions[0]
#       should.exist question
#       {outcome, active, processed} = question
#
#       should.exist outcome
#       outcome.should.be.equal false
#
#       should.exist active
#       active.should.be.equal false
#
#       should.exist processed
#       processed.should.be.equal true
#
#   it 'shouldn\'t mark commercial questions as processed because the inning still in progress', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures ClosedCommercialQuestionFixtures, mongodb
#     .then -> Questions.findOne({commercial: true})
#     .then (question) -> Questions.update {_id: question._id}, {$set: {inning: 4}}
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 1
#
#       question = questions[0]
#       should.exist question
#       {outcome, active, processed} = question
#
#       should.not.exist outcome
#
#       should.exist active
#       active.should.be.equal false
#
#       should.exist processed
#       processed.should.be.equal false
#
#   it 'should mark commercial questions as processed (inning in progress)', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveFullGameFixtures, mongodb
#     .then -> loadFixtures ClosedCommercialQuestionFixtures, mongodb
#     .then -> Questions.findOne({commercial: true})
#     .then (question) -> Questions.update {_id: question._id}, {$set: {inning: 4, outcomes: ["kKS"]}}
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Questions.find({commercial: true})
#     .then (questions) ->
#       should.exist questions
#       questions.should.be.an "array"
#       questions.length.should.be.equal 1
#
#       question = questions[0]
#       should.exist question
#       {outcome, active} = question
#
#       should.exist outcome
#       outcome.should.be.equal true
#
#       should.exist active
#       active.should.be.equal false
#
#   it 'should exchange coins on diamonds at the end of the game', ->
#     Promise.bind @
#     .then -> loadFixtures UnhandledFinishedGameFixtures, mongodb
#     .then -> loadFixtures UsersFixtures, mongodb
#     .then -> loadFixtures GamePlayedFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Users.findOne({_id: "Charlie"})
#     .then (user) ->
#       should.exist user
#       {profile} = user
#
#       should.exist profile
#       {diamonds} = profile
#
#       should.exist diamonds
#       diamonds.should.be.equal 51
#     .then -> Notifications.find({userId: "Charlie"})
#     .then (notifications) ->
#       should.exist notifications
#       notifications.should.be.an "array"
#       notifications.length.should.be.equal 3
#     .then -> Users.findOne({_id: "James"})
#     .then (user) ->
#       should.exist user
#       {profile} = user
#
#       should.exist profile
#       {diamonds} = profile
#
#       should.exist diamonds
#       diamonds.should.be.equal 42
#     .then -> Notifications.find({userId: "James"})
#     .then (notifications) ->
#       should.exist notifications
#       notifications.should.be.an "array"
#       notifications.length.should.be.equal 3
#
#   it 'shouldn\'t exchange coins more than once the end of the game', ->
#     Promise.bind @
#     .then -> loadFixtures UnhandledFinishedGameFixtures, mongodb
#     .then -> loadFixtures UsersFixtures, mongodb
#     .then -> loadFixtures GamePlayedFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Users.findOne({_id: "Charlie"})
#     .then (user) ->
#       should.exist user
#       {profile} = user
#
#       should.exist profile
#       {diamonds} = profile
#
#       should.exist diamonds
#       diamonds.should.be.equal 51
#
#   it 'should enrich the game by new fields', ->
#     Promise.bind @
#     .then -> loadFixtures ActiveGameEndOfPlayFixtures, mongodb
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) -> processGame.execute game
#     .then -> Games.findOne({id: activeGameId})
#     .then (game) ->
#       should.exist game
#       game.should.be.an "object"
#
#       {teams, outs, inning, topOfInning, playersOnBase, users, nonActive} = game
#
#       should.exist teams
#       teams.should.be.an "array"
#
#       home = _.findWhere teams, {teamId: "47f490cd-2f58-4ef7-9dfd-2ad6ba6c1ae8"}
#       should.exist home
#       home.should.be.an "object"
#
#       {batterNum, pitcher, battingLineUp} = home
#
#       should.exist batterNum
#       batterNum.should.equal (5 - 1)
#
#       should.exist pitcher
#       pitcher.should.be.an "array"
#
#       should.exist battingLineUp
#       battingLineUp.should.be.an "array"
#       battingLineUp.length.should.equal 10
#       ("cbfa52c5-ef2e-4d7c-8e28-0ec6a63c6c6f" in battingLineUp).should.equal true
#
#       away = _.findWhere teams, {teamId: "833a51a9-0d84-410f-bd77-da08c3e5e26e"}
#       should.exist away
#       away.should.be.an "object"
#
#       {batterNum, pitcher, battingLineUp} = away
#
#       should.exist batterNum
#       batterNum.should.equal (4 - 1)
#
#       should.exist pitcher
#       pitcher.should.be.an "array"
#
#       should.exist battingLineUp
#       battingLineUp.should.be.an "array"
#       battingLineUp.length.should.equal 10
#       ("92500d32-2314-4c7c-91c5-110f95229f9a" in battingLineUp).should.equal true
#
#       should.exist outs
#       outs.should.equal 2
#
#       should.exist inning
#       inning.should.equal 1
#
#       should.exist topOfInning
#       topOfInning.should.equal false
#
#       should.exist playersOnBase
#       playersOnBase.should.be.an "object"
#
#       {first, second, third} = playersOnBase
#
#       should.exist first
#       first.should.equal false
#
#       should.exist second
#       second.should.equal true
#
#       should.exist third
#       third.should.equal true
#
#       should.exist users
#       users.should.be.an "array"
#
#       should.exist nonActive
#       nonActive.should.be.an "array"
#
#   it 'should generate multipliers properly', ->
#     playerId = "9baf07d4-b1cb-4494-8c95-600d9e8de1a9"
#     bases =
#       first: true
#       second: false
#       third: false
#
#     Promise.bind @
#     .then -> loadFixtures PlayersFixtures, mongodb
#     .then -> processGame.calculateMultipliersForPitch playerId, 1, 2
#     .then (multipliers) ->
#       should.exist multipliers
#       multipliers.should.be.an "object"
#
#       {strike, ball, hit, out, foulball} = multipliers
#       should.exist strike
#       strike.should.be.a "number"
#
#       should.exist ball
#       ball.should.be.a "number"
#
#       should.exist hit
#       hit.should.be.a "number"
#
#       should.exist out
#       out.should.be.a "number"
#
#       should.exist foulball
#       foulball.should.be.a "number"
#     .then -> processGame.calculateMultipliersForPlay bases, playerId
#     .then (multipliers) ->
#       should.exist multipliers
#       multipliers.should.be.an "object"
#
#       {out, walk, single, double, triple, homerun} = multipliers
#       should.exist out
#       out.should.be.a "number"
#
#       should.exist walk
#       walk.should.be.a "number"
#
#       should.exist single
#       single.should.be.a "number"
#
#       should.exist double
#       double.should.be.a "number"
#
#       should.exist triple
#       triple.should.be.a "number"
#
#       should.exist homerun
#       homerun.should.be.a "number"
