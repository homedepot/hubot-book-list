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

module.exports = (robot) ->

  BOOK =
    TITLE: 0
    AUTHOR: 1
    CATEGORY: 2
    IMAGE: 3
    RATING: 4
    REVIEWCOUNT: 5

  TITLE_IMAGE = 'https://goo.gl/g5Itaz'


  robot.hear /booklist initialize/i, (res) ->
    if robot.brain.get('booklist')
      if robot.brain.get('booklist').length >= 0
        return emitString(res, "Booklist already exists")

    robot.brain.set('booklist', [])
    return emitString(res, "Booklist Initialized")

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

  robot.hear /booklist lookup (\d)$/i, (res) ->
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

  robot.hear /booklist edit (.*)$/i, (res) ->
    edit_args = res.match[1].split " "

    rating = 0
    nbrOfRatings = 0

    index = edit_args[0]
    if edit_args.length < 2 or isNaN(index)
      return emitString(res,"EDIT ERROR")
    else
      edit_args.shift()
      newTitle = edit_args.join(' ')
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
        { short: true, title: "Average Rating", value: if currentAverage.toString() }
      ]

    cb(payload, null)

  formatInfo = (data, avgRating, nbrOfReviews, cb) ->
    try
      book = data.items[0].volumeInfo
      author = book.authors[0]
      title = book.title
      category = if book.categories then book.categories[0] else "not set"
      image = if book.imageLinks.thumbnail then book.imageLinks.thumbnail else TITLE_IMAGE

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
