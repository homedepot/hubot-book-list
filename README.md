# hubot-book-list

[![wercker status](https://app.wercker.com/status/7e879584c6a7ec0ea53c333e45383a55/m "wercker status")](https://app.wercker.com/project/bykey/7e879584c6a7ec0ea53c333e45383a55)

Manages a list of books, using the google books api for data

See [`src/book-list.coffee`](src/book-list.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-book-list --save`

Then add **hubot-book-list** to your `external-scripts.json`:

```json
[
  "hubot-book-list"
]
```

## Sample Interaction

```
hubot booklist
```

![Example Image](./example.png)
