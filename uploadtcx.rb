require './connect'
require './nike'
require './activity'
require './logging'

require './config'

include Logging

abort "need tcx file name" unless ARGV.length > 0

nike = Nike.new(NIKE_USER, NIKE_PASSWORD)
data = Activity.new.parse_tcx(File.new(ARGV[0]))
abort unless data
run, gpx = nike.build_xml(data)
nike.send(run, gpx)
nike.complete