#TODO: If three or more, split up into separate files

export ledger = do
  parse-commodity = ->
    value = it.trim!.replace /[^\d.-]/ ''
    currency = it.replace value, '' .trim!
    currency: currency
    value: parse-float value

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
          throw new Error "Transaction with postings with empty values: #info"
        without := posting
        continue
      sum[posting.commodity.currency] ||= 0
      sum[posting.commodity.currency] += posting.commodity.value
      postings.push posting

    if without?
      for currency, value of sum
        postings.push do
          account: without.account
          commodity:
            currency: currency
            value: -value

    if postings.length > 2
      # TODO: Consider rudimentary intelligence for more than two postings
      throw new Error "Transactions with more than two postings are unsupported due to potential ambiguity of sources and destinations"

    source      = postings[0]
    destination = postings[1]

    # TODO: Support more than one currency
    if source.commodity.value > destination.commodity.value
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
    ledger.print!
      ..on \data do ->
        buffer = ''
        !->
          buffer += it
          while ~buffer.index-of \\n\n
            buffer .= split \\n\n
            buffer.shift! |> parse-transaction |> JSON.stringify |> (+ \\n) |> stream.push
            buffer .= join \\n\n

    return stream

export qif = (file) ->
  throw Error 'Not implemented'
  require! \qif2json
