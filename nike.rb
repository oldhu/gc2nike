require 'rubygems'
require 'mechanize'
require 'json'
require './logging'

class Mechanize
  def post(uri, query = {}, headers = {})
    return request_with_entity(:post, uri, query, headers) if String === query

    node = {}

    # Create a fake form
    class << node
      def search(*args); []; end
    end
    node['method'] = 'POST'
    node['enctype'] = 'application/x-www-form-urlencoded'

    form = Form.new(node)

    query.each { |k, v|
      if v.is_a?(IO)
        form.enctype = 'multipart/form-data'
        ul = Form::FileUpload.new({'name' => k.to_s},::File.basename(v.path))
        ul.mime_type = 'application/octet-stream'
        ul.file_data = v.read
        form.file_uploads << ul
      else
        form.fields << Form::Field.new({'name' => k.to_s},v)
      end
    }
    post_form(uri, form, headers)
  end
end

class BinaryIO < IO
  def initialize(str, path)
    @str = str
    @path = path
  end

  def path
    return @path
  end

  def read
    return @str
  end
end

class Nike
  include Logging

  CLIENT_ID = '9dfa1aef96a54441dfaac68c4410e063'
  CLIENT_SECRET = '3cbd1f1908bc1553'
  APP_NAME = 'nikeplusgps'
  USER_AGENT = 'NPConnect'

  LOGIN_DOMAIN = "secure-nikeplus.nike.com"
  LOGIN_PATH = "https://#{LOGIN_DOMAIN}/login/loginViaNike.do?mode=login"
  SYNC_PATH = "https://api.nike.com/v2.0/me/sync?access_token=%s"
  SYNC_COMPLETE_PATH = "https://api.nike.com/v2.0/me/sync/complete?access_token=%s"

  def initialize(user, pass)
    @agent = Mechanize.new { |a| a.ssl_version, a.verify_mode = 'SSLv3', OpenSSL::SSL::VERIFY_NONE }
    login(user, pass)
  end

  def add_cookie(key, value)
    cookie = Mechanize::Cookie.new :domain => LOGIN_DOMAIN, :name => key, :value => value, :path => '/'
    @agent.cookie_jar << cookie
  end

  def login(user, pass)
    logger.info "requesting to login into Nike Plus"
    add_cookie('app', APP_NAME)
    add_cookie('client_id', CLIENT_ID)
    add_cookie('client_secret', CLIENT_SECRET)
    res = @agent.post(
      LOGIN_PATH,
      { 'email' => user, 'password' => pass },
      { 'user-agent' => USER_AGENT, 'Accept' => 'application/json' } )
    @agent.cookie_jar.each do |c|
      if c.name == 'access_token' then
        @accessToken = c.value
        logger.info "got access token"
        return
      end
    end
    logger.error 'cannot login to nike plus'
    raise 'cannot login to nike plus'
  end

  def build_run_xml(data)
    logger.info "building run xml"
    startTime = Time.parse(data[0]).strftime("%FT%T+00:00")

    doc = REXML::Document.new
    doc.context[:attribute_quote] = :quote
    root = doc.add_element('sportsData')
    append_run_summary(root, startTime, data[1], data[2], data[3])
    append_misc(root, startTime)
    append_extended_data(root, data[4], data[5])
    doc << REXML::XMLDecl.new('1.0', 'UTF-8')
    o = ''
    doc.write(REXML::Output.new(o, "UTF-8"))
    logger.debug o
    return o
  end

  def build_gpx_xml(data)
    logger.info "trying to build gpx xml"
    return nil if data[6].length == 0
    logger.info "start to build gpx xml"
    doc = REXML::Document.new
    gpx = doc.add_element('gpx',
    {
      'xmlns' => 'http://www.topografix.com/GPX/1/1',
      'creator' => 'NikePlus',
      'version' => '1.1'
    })
    trk = gpx.add_element('trk')
    trk.add_element('name').text = REXML::CData.new('4c888a06')
    trk.add_element('desc').text = REXML::CData.new('workout')

    trkseg = trk.add_element('trkseg')
    data[6].each do |tp|
      trkpt = trkseg.add_element('trkpt',
      {
        'lat' => tp[1],
        'lon' => tp[2]
      })
      trkpt.add_element('ele').text = tp[3]
      trkpt.add_element('time').text = tp[0]
    end
    doc << REXML::XMLDecl.new('1.0', 'UTF-8')
    o = doc.to_s
    logger.debug o
    return o
  end

  # [startTime, totalSeconds, totalDistance, totalCalories, distance array, heart beat array, trackpoint array]
  def build_xml(data)
    run_xml = build_run_xml(data)
    gpx_xml = build_gpx_xml(data)
    return run_xml, gpx_xml
  end

  def send(run, gpx)
    logger.info "sending run xml and gpx xml"
    begin
      if gpx.nil? then
        payload = { 'runXML' => BinaryIO.new(run, 'runXML.xml') }
      else
        payload = { 'runXML' => BinaryIO.new(run, 'runXML.xml'),
          'gpxXML' => BinaryIO.new(gpx, 'gpxXML.xml') }
      end
      res = @agent.post(
      SYNC_PATH % @accessToken, payload,
      {
        'user-agent' => USER_AGENT,
        'appid' => 'NIKEPLUSGPS',
        'Referer' => nil,
        'Accept-Charset' => nil,
        'Accept-Language' => nil,
        'Accept' => nil
      })
      logger.info "sent"
    rescue Mechanize::ResponseCodeError => exception
      logger.error exception.page.header
      logger.error exception.page.content
    end
  end

  def complete
    logger.info "completing Nike Plus sync"
    res = @agent.post(
      SYNC_COMPLETE_PATH % @accessToken, {},
      {
        'user-agent' => USER_AGENT,
        'appid' => 'NIKEPLUSGPS',
        'Referer' => nil,
        'Accept-Charset' => nil,
        'Accept-Language' => nil,
        'Accept' => nil
      })
    logger.info "completed"
  end

  def append_run_summary(root, startTime, totalSeconds, totalDistance, totalCalories)
    summary = root.add_element('runSummary')
    summary.add_element('time').text = startTime
    summary.add_element('duration').text = (totalSeconds * 1000).to_i
    summary.add_element('distance', { 'unit' => 'km' }).text = "%.4f" % (totalDistance.to_f / 1000)
    summary.add_element('calories').text = totalCalories.to_i
    summary.add_element('battery')
  end

  def append_misc(root, startTime)
    root.add_element('template').add_element('templateName').text = REXML::CData.new("Basic")
    goal = root.add_element('goal', {'type' => '', 'value' => '', 'unit' => ''})

    userInfo = root.add_element('userInfo')
    userInfo.add_element('empedID').text = 'XXXXXXXXXXX'
    userInfo.add_element('weight')
    userInfo.add_element('device').text = 'iPod'
    userInfo.add_element('calibration')

    root.add_element('startTime').text = startTime
  end

  def append_extended_data(root, distance, hr)
    ext = root.add_element('extendedDataList')
    ext.add_element('extendedData',
      {
        'dataType' => 'distance',
        'intervalType' => 'time',
        'intervalUnit' => 's',
        'intervalValue' => 10
      }).text = REXML::CData.new(distance.map { |x| "%.4f" % (x.to_f / 1000) } .join(', '))

    ext.add_element('extendedData',
      {
        'dataType' => 'heartRate',
        'intervalType' => 'time',
        'intervalUnit' => 's',
        'intervalValue' => 10
      }).text = REXML::CData.new(hr.map { |x| x.to_i } .join(', '))

  end

end