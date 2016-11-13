``#!/usr/bin/env node``

require! [ fs, tmp ]

unless [ \ledger, \qif ].includes process.argv[2]
  console.error "Usage: #{process.argv[1]} (ledger | qif)"
  return

process.stdout.on \error !-> process.exit 0 if it.code is \EPIPE

tmp.file-sync!.name
  .. |> fs.create-write-stream |> process.stdin.pipe
  .. |> require './parsers.js' .[process.argv[2]]
    ..pipe process.stdout

