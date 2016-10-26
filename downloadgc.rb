require './connect'
require './nike'
require './activity'
require './logging'

require './config'

include Logging

abort "need last activity id" unless ARGV.length > 0
activity_id = ARGV[0]

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

con = Connect.new

download_tcx(con, activity_id)

con.each_activity_before_activity(activity_id) do |id|
    download_tcx(con, id)
end