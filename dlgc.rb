require './connect'
require './nike'
require './activity'
require './logging'

include Logging

def save_progress(id)
  File.open("dlgc.last", "w") { |f| f.write(id) }
end

def read_progress
  return nil unless File.exist?("dlgc.last")
  File.read("dlgc.last")
end

def get_tcx_date(tcx)
  data = Activity.new.parse_tcx_header(tcx)
  return data[0][0,10]
end

def download_tcx(con, id)
  tcx = con.get_tcx(id)
  return if tcx.nil?
  date = get_tcx_date(tcx)
  File.open("tcx/#{date}-#{id}.tcx", "w") { |f| f.write(tcx) }    
end

activity_id = read_progress

if activity_id.nil?
  abort "need last activity id" unless ARGV.length > 0
  activity_id = ARGV[0]
end

con = Connect.new

logger.info "trying to find activity after #{activity_id}"
last_id = nil

con.each_activity_after_activity(activity_id) do |id|
  logger.info "got activity #{activity_id}"
  download_tcx(con, id)
  save_progress(id)
  last_id = id
end

logger.info "no activity found" unless last_id