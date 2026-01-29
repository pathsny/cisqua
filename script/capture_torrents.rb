#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/libs'
require 'json'

# Set up transmission capture mode
TransmissionStub.instance.use_file('data/test_data/torrents.json', mode: :capture)

# Initialize Transmission RPC client
rpc = Transmission::RPC.new(
  host: 'localhost',
  port: 9091,
  ssl: false,
  credentials: {
    username: 'transmission',
    password: 'transmission'
  }
)

# Get all torrents - this will trigger the capture
torrents = Transmission::Model::Torrent.all(connector: rpc).torrents

puts "Captured #{torrents.size} torrents to data/test_data/torrents.json"
