#TODO: If three or more, split up into separate files

export ledger = do
  parse-commodity = ->
    value = it.trim!.replace /[^\d.-]/ ''
    currency = it.replace value, '' .trim!
    currency: currency
    value: parse-float value

  parse-info = -> it

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

    info = lines.shift!
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

    { info, postings }

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
