require './connect'
require './nike'
require './activity'
require './logging'

require './config'

include Logging

def save_progress(time)
    File.open("gc2nike.last", "w") { |f| f.write(time) }
end

def read_progress
    return nil unless File.exist?("gc2nike.last")
    File.read("gc2nike.last")
end

logger.info "=" * 80

con = Connect.new(GC_USER, GC_PASSWORD)
nike = Nike.new(NIKE_USER, NIKE_PASSWORD)

con.each_activity_after(read_progress) do |id|
    logger.info "downloading activity #{id}"
    tcx = con.get_tcx(id)
    data = Activity.new.parse_tcx(tcx)
    run, gpx = nike.build_xml(data)
    nike.send(run, gpx)
    save_progress(data[0])
    break
end

nike.complete

