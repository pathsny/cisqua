describe Cisqua::TorrentProcessor do
  before do
    TransmissionStub.instance.register_middleware
    TransmissionStub.instance.use_file(File.join(
      Cisqua::TEST_DATA_FOLDER,
      'torrents_sync_1.json',
    ))
    Cisqua::TorrentProcessor.instance.sync_torrents
  end

  it 'syncs torrent hashes downloading to the monitored folder' do
    MONITORED_TORRENTS.each do |torrent_name|
      expect(Cisqua::TorrentHash.find_by_hash_string(TORRENT_HASHES[torrent_name])).to be_present
    end
  end

  it 'ignores torrents not downloading to the monitored folder' do
    expect(Cisqua::TorrentHash.find_by_hash_string(TORRENT_HASHES['The Villainess'])).not_to be_present
  end

  context 'with second sync' do
    before do
      TransmissionStub.instance.use_file(File.join(
        Cisqua::TEST_DATA_FOLDER,
        'torrents_sync_2.json',
      ))
      Cisqua::TorrentProcessor.instance.sync_torrents
    end
  end

  # it 'has an active torrent for each hash' do
  #   hash = Cisqua::TorrentHash.find_by_hash_string(TORRENT_HASHES['FF7 Advent Children'])
  #   torrent = hash.listed_torrent
  #   expect(torrent.name).to be_equal(
  #     '[Yousei-raws] Final Fantasy VII Advent Children Complete [BDrip 1920x1080 x264 TrueHD]',
  #   )
  # end

  # it 'correctly sets basic torrent attributes' do
  #   torrent = Cisqua::Torrent.find_by_hash_string('12978720018f235dcce76467f13cdc96dc1127b7')
  #   expect(torrent).to be_present
  #   expect(torrent.name).to be_present
  #   expect(torrent.download_dir).to be_present
  #   expect(torrent.total_size).to be > 0
  #   expect(torrent.file_count).to be > 0
  # end

  # it 'correctly maps torrent statuses' do
  #   torrent = Cisqua::Torrent.find_by_hash_string('12978720018f235dcce76467f13cdc96dc1127b7')
  #   expect(torrent.status_name).to be_in(%i[stopped queue_verification verifying queue_download downloading
  #                                           queue_seeding seeding])
  # end

  # it 'properly associates torrent files' do
  #   torrent = Cisqua::Torrent.find_by_hash_string('12978720018f235dcce76467f13cdc96dc1127b7')
  #   expect(torrent.files).to be_present
  #   expect(torrent.files.count).to eq(torrent.file_count)

  #   torrent.files.each do |file|
  #     expect(file.name).to be_present
  #     expect(file.length).to be > 0
  #     expect(file.bytes_completed).to be >= 0
  #     expect(file.bytes_completed).to be <= file.length
  #   end
  # end

  # it 'maintains torrent hash relationships' do
  #   torrent = Cisqua::Torrent.find_by_hash_string('12978720018f235dcce76467f13cdc96dc1127b7')
  #   torrent_hash = Cisqua::TorrentHash.find_by_hash_string('12978720018f235dcce76467f13cdc96dc1127b7')

  #   expect(torrent_hash).to be_present
  #   expect(torrent_hash.listed_torrent).to eq(torrent)
  #   expect(torrent_hash.hash_string).to eq(torrent.hash_string)
  # end

  # it 'handles error states correctly' do
  #   torrent = Cisqua::Torrent.find_by_hash_string('12978720018f235dcce76467f13cdc96dc1127b7')
  #   if torrent.error?
  #     expect(torrent.error_string).to be_present
  #     expect(torrent.error).to be > 0
  #   end
  # end

  # it 'maintains proper progress tracking' do
  #   torrent = Cisqua::Torrent.find_by_hash_string('12978720018f235dcce76467f13cdc96dc1127b7')
  #   expect(torrent.percent_done).to be >= 0
  #   expect(torrent.percent_done).to be <= 1.0

  #   if torrent.percent_done == 1.0
  #     expect(torrent.done_date).to be_present
  #   end
  # end
end

TORRENT_HASHES = {
  'The Villainess' => '6c5f098d5877a2febc65f64c0c1a7cde72679cd6',
  'Made In Abyss' => '12978720018f235dcce76467f13cdc96dc1127b7',
  'FF7 Advent Children' => 'c542f52c90fccb4f014d34e1bebdd264fb66e379',
  'Frieren' => 'f03841b6b24585b1571df6b0c930d9946047058f',
}.freeze

MONITORED_TORRENTS = %w[
  Made In Abyss
  FF7 Advent Children
  Frieren
].freeze
