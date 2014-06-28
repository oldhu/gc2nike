require './connect'
require './nike'
require './activity'
require './logging'

require './config'

include Logging

def save_progress(id)
    File.open("gc2nike.last", "w") { |f| f.write(id) }
end

def read_progress
    return nil unless File.exist?("gc2nike.last")
    File.read("gc2nike.last")
end

logger.info "=" * 60

con = Connect.new
nike = nil

activity_id = read_progress || ACTIVITY_ID

con.each_activity_after_activity(activity_id) do |id|
    nike ||= Nike.new(NIKE_USER, NIKE_PASSWORD)
    logger.info "downloading activity #{id}"
    tcx = con.get_tcx(id)
    data = Activity.new.parse_tcx(tcx)
    if data[4].length > 0 then
        run, gpx = nike.build_xml(data)
        nike.send(run, gpx)
    else
        logger.info "skip empty activity"
    end
    save_progress(id)
end

nike.complete unless nike.nil?

