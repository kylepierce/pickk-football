createDependencies = require "../../../helper/dependencies"
settings = (require "../../../helper/settings")("#{process.env.ROOT_DIR}/settings/test.json")
Promise = require "bluebird"
moment = require "moment"
_ = require "underscore"
nock = require "nock"

describe "stats API", ->
  dependencies = createDependencies settings, "PickkImport"

  date = moment("2017-08-19").toDate() # in fact 2016-06-11 because of time zone shift
  gameId = 1744080
  teamId = "833a51a9-0d84-410f-bd77-da08c3e5e26e"

  it 'fetch scheduled games for one day', ->
    new Promise (resolve, reject) ->
      nock.back "../../fixtures/api/stats/getScheduledGames.json", (recordingDone) ->
        Promise.bind @
          .then -> dependencies.stats.getScheduledGames date, 1
          .then (result) ->
            should.exist result

            {apiResults} = result
            should.exist apiResults
            apiResults.should.be.an "array"

            {league} = apiResults[0]
            should.exist league

            {season} = league
            should.exist season

            {eventType} = season
            should.exist eventType

            {events} = eventType[0]
            should.exist events
            events.should.be.an "array"
            events.length.should.be.equal 13

        .then @assertScopesFinished
        .then resolve
        .catch reject
        .finally recordingDone

  it 'should check whether detailed information about the game are fetched', ->
    @timeout(10000)

    new Promise (resolve, reject) ->
      nock.back "../../fixtures/api/stats/getPlayByPlay.json", (recordingDone) ->
        Promise.bind @
          .then -> dependencies.stats.getPlayByPlay gameId
          .then (result) ->
            should.exist result
            {status} = result
            status.should.be.equal "OK"
            {apiResults} = result
            should.exist apiResults
            apiResults.should.be.an "array"

            {league} = apiResults[0]
            should.exist league
            {season} = league
            {eventType} = season
            {events} = eventType[0]
            should.exist events
            events.should.be.an "array"
            {eventId} = events[0]
            should.exist eventId
            eventId.should.be.equal gameId

            {pbp} = events[0]
            should.exist pbp
            events.should.be.an "array"
            pbp.length.should.be.equal 168

          .then @assertScopesFinished
          .then resolve
          .catch reject
          .finally recordingDone
