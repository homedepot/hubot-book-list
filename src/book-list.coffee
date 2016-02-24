# Description
#   Manages a list of books, using the google books api for data
#
# Commands:
#   hubot booklist random - Returns a random book
#   hubot booklist add <title> - adds the book to the booklist
#   hubot booklist lookup <index> - retrieves book information
#   hubot booklist - displays full booklist
#   hubot booklist edit <index> <title> - edit book at index with new title
#   hubot booklist review book <index> stars <rating> - rates the selected book
#
# Author:
#   Thomas Gamble & Paul Gaffney
#
# Title image by Alejandro Escamilla - hosted by unsplash.com with CCO-1.0 License

Github = require('github-api')

module.exports = (robot) ->

  BOOK =
    TITLE: 0
    AUTHOR: 1
    CATEGORY: 2
    IMAGE: 3
    RATING: 4
    REVIEWCOUNT: 5

  TITLE_IMAGE = 'https://goo.gl/g5Itaz'

  TOKEN = process.env.HUBOT_GITHUB_TOKEN
  GITHUB_USER = process.env.HUBOT_GITHUB_USER
  GITHUB_REPO = process.env.HUBOT_GITHUB_REPO
  GITHUB_FILE = process.env.HUBOT_GITHUB_FILE


  robot.hear /booklist initialize/i, (res) ->
    if robot.brain.get('booklist')
      if robot.brain.get('booklist').length >= 0
        return emitString(res, "Booklist already exists")

    robot.brain.set('booklist', [])
    return emitString(res, "Booklist Initialized")

  prepRepo = (res, cb) ->
    #github = new Github {token: TOKEN, auth: "oauth"}
    #if process.env.HUBOT_GITHUB_URL
    github = new Github {apiUrl: "#{process.env.HUBOT_GITHUB_URL}/api/v3", token: TOKEN, auth: "oauth"}
    email = "hubot@hubot.com"
    user = "hubot"
    if res.user
      if res.user.name
        user = res.user.name
      if res.user.email_address
        email = res.user.email_address
    options = {
      author: {
        name: user
        email: email
      }
      committer: {
        name: user
        email: email
      }
      encode: true
    }
    repo = github.getRepo GITHUB_USER, GITHUB_REPO
    cb(repo, options)

  robot.hear /booklist db (.*)$/i, (res) ->
    booklist = getBookList()
    if res.match[1] == "save"
      if booklist and booklist.length > 0
        prepRepo res, (repo, options) ->
          repo.write 'master', GITHUB_FILE, JSON.stringify(booklist), "hubot", options, (err) ->
            if err
              console.log err
              emitString(res, "BACKUP ERROR -" + err)
            else
              console.log "no error"
              emitString(res, "Booklist backed up")
      else
        return emitString(res, "Unable to backup empty booklist")
    if res.match[1] == "load"
      if booklist and booklist.length > 0
        return emitString(res, "Booklist already exists")
      else
        prepRepo res, (repo, options) ->
          repo.read 'master', GITHUB_FILE, (err, data) ->
            if err
              return emitString("RELOAD ERROR - " + err) if err
            else
              robot.brain.set('booklist', data)
              return emitString(res, "Booklist re-loaded")

  robot.hear /booklist add (.*)$/i, (res) ->
    rawBookToAdd = res.match[1]
    rating = 0
    nbrOfReviews = 0

    addBook res, rawBookToAdd, rating, nbrOfReviews, null, (err) ->

      return emitString(res,"ADD ERROR - #{err}") if err

      formatBookInfo getLastBook(), "Added: ", (book, err) ->

        return emitString(res,"ADD ERROR - #{err}") if err

        robot.emit 'slack-attachment',
          channel: res.envelope.room
          content: book

  robot.hear /booklist review book (\d{1,5}) stars (\d{1})/i, (res) ->
    index = res.match[1]
    reviewRating = parseInt(res.match[2], 10)

    if reviewRating > 5
      return emitString(res,"Ratings must be between 1 and 5")

    maxIndex = getBookList().length - 1
    if index > maxIndex
      return emitString(res,"BOOK DOES NOT EXIST ERROR")
    else
      addReview index, reviewRating

      formatBookInfo getBookAtIndex(index), "Reviewed: #{index} - ", (formattedBook, err) ->

        return emitString(res,"EDIT ERROR - #{err}") if err
        robot.emit 'slack-attachment',
          channel: res.envelope.room
          content: formattedBook

  robot.hear /booklist random/i, (res) ->
    booklist = getBookList()
    if booklist.length == 0
      return emitString(res, "no-books")
    else
      randomBook = res.random getBookList()
      index = getBookList().indexOf(randomBook)
      formatBookInfo randomBook, "Random - #{index}: ", (book, err) ->

        return emitString(res,"RANDOM ERROR - #{err}") if err

        robot.emit 'slack-attachment',
          channel: res.envelope.room
          content: book

  robot.hear /booklist$/i, (res) ->
    booklist = getBookList()
    return emitString(res, "Null booklist") if booklist is null
    if booklist.length == 0
      return emitString(res,"no-books")
    else
      fields = []

      booklist.map (book) ->
        fields.push
          title: "#{booklist.indexOf(book)} - #{book[BOOK.TITLE].value}"
          value: "#{book[BOOK.AUTHOR].value}, #{book[BOOK.CATEGORY].value}"

      payload =
        title: "Booklist - #{getBookList().length} books"
        thumb_url: TITLE_IMAGE
        fields: fields

      robot.emit 'slack-attachment',
        channel: res.envelope.room
        content: payload

  robot.hear /booklist lookup (\d{1,20})$/i, (res) ->
    index = res.match[1]
    maxIndex = getBookList().length - 1
    if index > maxIndex
      return emitString(res,"LOOKUP ERROR")
    else
      formatBookInfo getBookAtIndex(index), "Index #{index}: ", (book, err) ->

        return emitString(res,"LOOKUP ERROR - #{err}") if err

        robot.emit 'slack-attachment',
          channel: res.envelope.room
          content: book

  robot.hear /booklist edit (\d{1,20}) (.*)$/i, (res) ->
    rating = 0
    nbrOfRatings = 0

    index = res.match[1]

    newTitle = res.match[2]
    maxIndex = getBookList().length - 1
    if index > maxIndex
      return emitString(res,"EDIT ERROR")
    else
      addBook res, newTitle, rating, nbrOfRatings, index, (err) ->
        return emitString(res,"EDIT ERROR - #{err}") if err


        formatBookInfo getBookAtIndex(index), "Updated: #{index} is ", (book, err) ->

          return emitString(res,"EDIT ERROR - #{err}") if err

          robot.emit 'slack-attachment',
            channel: res.envelope.room
            content: book

  getBookAtIndex = (index) ->
    getBookList()[index]

  getBookList = ->
    robot.brain.get('booklist')


  addBook = (msg, title, rating, nbrOfReviews, index, cb) ->
    bookEnhancementQuery msg, title, (data, err) ->
      return cb err if err

      formatInfo data, rating, nbrOfReviews, (enhancedBook, err) ->
        return cb err if err

        booklist = getBookList()
        if index
          getBookList()[index] = enhancedBook
        else
          booklist.push enhancedBook
        cb err

  addReview = (index, newRating) ->
    book = getBookAtIndex(index)
    newRating = parseInt(newRating, 10)

    currentAverage = 0
    nbrOfReviews = 0

    if book[BOOK.RATING] and book[BOOK.REVIEWCOUNT]
      currentAverage = book[BOOK.RATING].value
      nbrOfReviews = book[BOOK.REVIEWCOUNT].value

    newTotalOfAllRatings = currentAverage * nbrOfReviews + newRating

    nbrOfReviews++

    newAverage = newTotalOfAllRatings / nbrOfReviews

    book[BOOK.RATING].value = newAverage
    book[BOOK.REVIEWCOUNT].value = nbrOfReviews

  getLastBook = ->
    booklist = getBookList()
    last = booklist.length - 1
    getBookAtIndex(last)

  emitString = (res, string="Error") ->
    payload =
      title: string
    robot.emit 'slack-attachment',
      channel: res.envelope.room
      content: payload

  formatBookInfo = (book, action, cb) ->
    currentAverage = 0

    if book[BOOK.RATING] and book[BOOK.REVIEWCOUNT]
      currentAverage = book[BOOK.RATING].value

    payload =
      title: action + book[BOOK.TITLE].value
      thumb_url: book[BOOK.IMAGE].value
      fields: [
        { short: true, title: "Author", value: book[BOOK.AUTHOR].value }
        { short: true, title: "Category", value: book[BOOK.CATEGORY].value }
        { short: true, title: "Average Rating", value: currentAverage }
      ]

    cb(payload, null)

  formatInfo = (data, avgRating, nbrOfReviews, cb) ->
    try
      book = data.items[0].volumeInfo
      author = book.authors[0]
      title = book.title
      category = if book.categories then book.categories[0] else "not set"
      image = if book.imageLinks then book.imageLinks.thumbnail else TITLE_IMAGE

    catch err
      return cb(enhancedBook, err)

    enhancedBook = []
    enhancedBook.push
      key: "Title"
      value: title

    enhancedBook.push
      key: "Author"
      value: author

    enhancedBook.push
      key: "Category"
      value: category

    enhancedBook.push
      key: "Image"
      value: image

    enhancedBook.push
      key: "Average Rating"
      value: avgRating

    enhancedBook.push
      key: "Number of Reviews"
      value: nbrOfReviews

    cb(enhancedBook, err)

  bookEnhancementQuery = (res, search_terms, cb) ->
    res.http("https://www.googleapis.com/books/v1/volumes?q='#{search_terms}'&maxResults=1")
    .get() (err, resp, body) ->
      if(err)
        err = "Lookup Error - #{err}"
      else
        try
          data = JSON.parse body
          if not data.items
            err = "Lookup Error - search failed for title: #{search_terms}"
        catch err
          err = "Lookup Error - #{err}"
      cb(data, err)
