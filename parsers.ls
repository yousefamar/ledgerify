#TODO: If three or more, split up into separate files

export ledger = do
  parse-commodity = ->
    amount = it.trim!.replace /[^\d.-]/ ''
    currency = it.replace amount, '' .trim!
    currency: currency
    amount: parse-float amount

  parse-info = ->
    info = {}
    it .= split ' '
    dates = it.shift!.split \=
    info.timestamp = Date.parse dates[0]
    if dates.length > 1 then info.effective-timestamp = Date.parse dates[1]
    info.cleared = true
    if it[0] is \!
      info.cleared = false
    else if it[0] is \*
      it.shift!
    it .= join ' '
    info.description = it
    info

  parse-posting = ->
    # TODO: Ignore comments
    parts = it.trim!.split /(?:\t|[ ]{2,})+/
    posting = {}
    if parts.length < 2
      return account: parts[0]
    else
      return account: parts[0], commodity: parse-commodity parts[1]

  parse-transaction = ->
    lines = it.split \\n

    info = parse-info lines.shift!
    postings = []

    sum = {}
    without = null

    for posting in lines
      posting = parse-posting posting
      unless posting.commodity?
        if without?
          throw new Error "Transaction with postings with empty commodity amounts:\n#it"
        without := posting
        continue
      sum[posting.commodity.currency] ||= 0
      sum[posting.commodity.currency] += posting.commodity.amount
      postings.push posting

    if without?
      for currency, amount of sum
        postings.push do
          account: without.account
          commodity:
            currency: currency
            amount: -amount

    if postings.length > 2
      # TODO: Consider rudimentary intelligence for more than two postings
      throw new Error "Transactions with more than two postings are unsupported due to potential ambiguity of sources and destinations"

    source      = postings[0]
    destination = postings[1]

    # TODO: Support more than one currency
    if source.commodity.amount > destination.commodity.amount
      temp        = source
      source      = destination
      destination = temp

    transaction = {} <<<< info
      ..source      = source.account
      ..destination = destination.account
      ..commodity   = destination.commodity

  (file) ->
    require! { stream, \ledger-cli : { Ledger } }

    ledger = new Ledger do
      binary: '/usr/bin/ledger'
      file: file

    stream = new stream.Readable!
    stream._read = ->
    buffer = ''
    ledger.print!
      ..on \data !->
        buffer += it
        while ~buffer.index-of \\n\n
          buffer .= split \\n\n
          buffer.shift! |> parse-transaction |> JSON.stringify |> (+ \\n) |> stream.push
          buffer .= join \\n\n
      ..on \end !->
          buffer.trim! |> parse-transaction |> JSON.stringify |> (+ \\n) |> stream.push

    return stream

export qif = (file) ->
  require! [ stream, qif2json ]
  stream = new stream.Readable!
  stream._read = ->
  qif2json.parse-file file, (err, data) !->
    throw err if err?
    data.transactions
      ..for-each !->
        # TODO: Warn user that we don't use US dates, and also drop QIF because it's a terrible format
        it.date .= split \/
        temp = it.date[0]
        it.date[0] = it.date[1]
        it.date[1] = temp
        it.date .= join \/
        it.date = Date.parse it.date
      ..sort (a, b) -> a.date - b.date
      ..for-each !->
        # TODO: Allow specification of defaults for information QIF does not support
        do
          timestamp: it.date
          cleared: true
          description: it.payee
          source: null
          destination: null
          commodity:
            currency: null
            amount: it.amount
        |> JSON.stringify |> (+ \\n) |> stream.push

  return stream
