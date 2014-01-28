require './connect'
require './nike'
require './activity'
require './logging'

include Logging

con = Connect.new('hhhhtj', 'deqrpl')
nike = Nike.new('hutiejun@gmail.com', 'Deqrpl8613')

con.each_activity do |id|
    logger.info "downloading activity #{id}"
    tcx = con.get_tcx(id)
    data = Activity.new.parse_tcx(tcx)
    run, gpx = nike.build_xml(data)
    nike.send(run, gpx)
    break
end

nike.complete

