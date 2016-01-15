Helper = require('hubot-test-helper')
helper = new Helper('./../src/book-list.coffee')

chai = require 'chai'
chai.use require 'sinon-chai'
expect = chai.expect

nock = require 'nock'
sinon = require 'sinon'

responseBody =
  valid_coder:
    '{ "items": [ { "volumeInfo": { "title": "The Clean Coder", "subtitle": "A Code of Conduct
    for Professional Programmers", "authors": [ "Robert C. Martin" ], "categories": [ "Computers" ],
    "imageLinks": { "smallThumbnail": "http://smallCoder","thumbnail": "http://bigCoder"} } } ] }'
  valid_prag_program:
    '{ "items": [ { "volumeInfo": { "title": "The Pragmatic Programmer", "subtitle":
    "A Code of Conduct for Professional Programmers", "authors": [ "Andrew Hunt", "David Thomas" ], "categories":
    [  "Computers" ], "imageLinks": { "smallThumbnail": "http://smallPrag","thumbnail": "http://bigPrag"} } } ] }'
  valid_book2:
    '{ "items": [ { "volumeInfo": { "title": "Book 2",  "authors": [ "Author 2", "Author 2a" ],
    "categories": [ "Computers" ], "imageLinks": { "smallThumbnail": "http://small2","thumbnail":
    "http://big2"} } } ] }'
  valid_book3:
    '{ "items": [ { "volumeInfo": { "title": "Book 3",  "authors": [ "Author 3", "Author3a",
    "Author3b" ], "categories": [ "Computers" ],"imageLinks": { "smallThumbnail": "http://small3", "thumbnail":
    "http://big3"} } } ] }'
  valid_book4:
    '{ "items": [ { "volumeInfo": { "title": "Book 4",  "authors": [ "Author 4" ], "categories":
    [ "Computers" ], "imageLinks": { "smallThumbnail": "http://small4", "thumbnail": "http://big4"} } } ] }'

describe 'book list', ->
  room = null

  beforeEach ->
    room = helper.createRoom()

    do nock.disableNetConnect
    nock("https://www.googleapis.com")
    .get("/books/v1/volumes?q='clean%20coder'&maxResults=1")
    .reply 200, responseBody.valid_coder
    .get("/books/v1/volumes?q='Book%204'&maxResults=1")
    .reply 200, responseBody.valid_book4
    .get("/books/v1/volumes?q='Book%202'&maxResults=1")
    .reply 200, responseBody.valid_book2
    .get("/books/v1/volumes?q='Book%203'&maxResults=1")
    .reply 200, responseBody.valid_book3
    .get("/books/v1/volumes?q='pragmatic%20programmer'&maxResults=1")
    .reply 200, responseBody.valid_prag_program

  afterEach ->
    room.destroy()
    nock.cleanAll()

  describe 'user asks hubot to display an un-initialized booklist', ->

    beforeEach  ->
      room.robot.emit = sinon.spy()
      room.user.say 'mary', 'hubot booklist'

    it 'and it should reply with a response indicating that the booklist is not initialized', ->
      expect(room.robot.emit.firstCall.args[1].content.title).equals("Null booklist")

  describe 'user asks hubot to initialize booklist', ->

    beforeEach (done)  ->
      room.robot.emit = sinon.spy()
      room.user.say 'mary', 'hubot booklist initialize'
      setTimeout done, 100

    it 'and it should reply with a response indicating that the booklist was initialized', ->
      expect(room.robot.emit.firstCall.args[1].content.title).equals("Booklist Initialized")

    describe 'user asks hubot to initialize booklist', ->

      beforeEach (done)  ->
        room.robot.emit = sinon.spy()
        room.user.say 'mary', 'hubot booklist initialize'
        setTimeout done, 100

      it 'and it should reply with a response indicating that the booklist already exists', ->
        expect(room.robot.emit.firstCall.args[1].content.title).equals("Booklist already exists")

    describe 'user asks hubot to display booklist', ->

      beforeEach  ->
        room.robot.emit = sinon.spy()
        room.user.say 'mary', 'hubot booklist'

      it 'and it should reply with a no-books response when there are no books in the list', ->
        expect(room.robot.emit.firstCall.args[1].content.title).equals("no-books")

    describe 'user asks hubot to add books', ->

      beforeEach (done) ->
        room.robot.emit = sinon.spy()
        room.user.say 'alice', 'hubot booklist add nonsense'
        room.user.say 'mary', 'hubot booklist add clean coder'
        room.user.say 'alice', 'hubot booklist add Book 2'
        room.user.say 'alice', 'hubot booklist add Book 3'
        room.user.say 'alice', 'hubot booklist add Book 4'
        setTimeout done, 100

      it 'and it should reply with an error for invalid books',  ->
        expect(room.robot.emit.firstCall.args[1].content.title).to.match(/ADD ERROR - Lookup Error - (.*)$/)

      it 'and it should reply confirming the addition of the first book',  ->
        expect(room.robot.emit.secondCall.args[1].content.title).equals("Added: The Clean Coder")

      it 'and it should reply confirming the addition of the second book',  ->
        expect(room.robot.emit.thirdCall.args[1].content.fields[0].value).equals("Author 2")

      it 'and it should reply confirming the addition of the third book',  ->
        expect(room.robot.emit.getCall(3).args[1].content.fields[1].value).equals("Computers")

      it 'and it should reply confirming the addition of the fourth book',  ->
        expect(room.robot.emit.lastCall.args[1].content.thumb_url).equals("http://big4")

      describe 'then asks to see the booklist', ->

        beforeEach (done) ->
          room.robot.emit = sinon.spy()
          room.user.say 'alice', 'hubot booklist'
          setTimeout done, 20

        it 'and it should reply with the full book list', ->
          expect(room.robot.emit.firstCall.args[1].content.title).equals("Booklist - 4 books")
          expect(room.robot.emit.firstCall.args[1].content.thumb_url).equals("https://goo.gl/g5Itaz")
          expect(room.robot.emit.firstCall.args[1].content.fields[3].title).equals("3 - Book 4")
          expect(room.robot.emit.firstCall.args[1].content.fields[3].value).equals("Author 4, Computers")

      describe 'then asks for a specific book by index number', ->

        beforeEach ->
          room.robot.emit = sinon.spy()
          room.user.say 'alice', 'hubot booklist lookup 2'
          room.user.say 'alice', 'hubot booklist lookup 4'
          room.user.say 'alice', 'hubot booklist lookup junk'

        it 'and it should reply including the title and index of the book requested', ->
          expect(room.robot.emit.firstCall.args[1].content.title).equals("Index 2: Book 3")

        it 'and it should reply including the author of the book requested', ->
          expect(room.robot.emit.firstCall.args[1].content.fields[0].value).equals("Author 3")

        it 'and it should reply including the category of the book requested', ->
          expect(room.robot.emit.firstCall.args[1].content.fields[1].value).equals("Computers")

        it 'and it should reply including the image url of the book requested', ->
          expect(room.robot.emit.firstCall.args[1].content.thumb_url).equals("http://big3")

        it 'and it should reply with an error for indexes that do not exist', ->
          expect(room.robot.emit.secondCall.args[1].content.title).equals("LOOKUP ERROR")
          expect(room.robot.emit.lastCall.args[1].content.title).equals("LOOKUP ERROR")

      describe 'then asks for info on a random book', ->

        beforeEach ->
          room.robot.emit = sinon.spy()
          room.user.say 'alice', 'hubot booklist random'

        it 'and it should reply with a random book to alice', ->
          expect(room.robot.emit.firstCall.args[1].content.title).to.match(/Random - (\d): (.*)$/)

      describe 'then makes a book edit', ->

        beforeEach (done) ->
          room.robot.emit = sinon.spy()
          room.user.say 'alice', 'hubot booklist edit junk'
          room.user.say 'alice', 'hubot booklist edit 0'
          room.user.say 'alice', 'hubot booklist edit 2 pragmatic programmer'
          setTimeout done, 10

        it 'and it should reply with an edit error', ->
          expect(room.robot.emit.firstCall.args[1].content.title).equals("EDIT ERROR")
          expect(room.robot.emit.secondCall.args[1].content.title).equals("EDIT ERROR")

        it 'and it should reply with a confirmation of the edit', ->
          expect(room.robot.emit.lastCall.args[1].content.title).equals("Updated: 2 is The Pragmatic Programmer")

        describe 'then looks up an edited a book', ->

          beforeEach (done) ->
            room.robot.emit = sinon.spy()
            room.user.say 'alice', 'hubot booklist lookup 2'
            setTimeout done, 10


          it 'and it should reply including the title and index of the book requested', ->
            expect(room.robot.emit.firstCall.args[1].content.title).equals("Index 2: The Pragmatic Programmer")

          it 'and it should reply including the author of the book requested', ->
            expect(room.robot.emit.firstCall.args[1].content.fields[0].value).equals("Andrew Hunt")

          it 'and it should reply including the category of the book requested', ->
            expect(room.robot.emit.firstCall.args[1].content.fields[1].value).equals("Computers")

          it 'and it should reply including the image url of the book requested', ->
            expect(room.robot.emit.firstCall.args[1].content.thumb_url).equals("http://bigPrag")

