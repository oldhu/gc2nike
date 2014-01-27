require 'rubygems'
require 'mechanize'
require 'json'
require 'rexml/document'
require 'time'

require './simplespliner'

base = 'https://connect.garmin.com'

base_uri = URI(base)
LOGIN_PATH = "#{base}/signin/"
QUERY_PATH = "#{base}/proxy/activity-search-service-1.2/json/activities?start=%d"
TCX_PATH = "#{base}/proxy/activity-service-1.0/tcx/activity/%d?full=true"

# http://connect.garmin.com/proxy/activity-search-service-1.2/json/activities?beginTimestamp%3E2014-01-17T04:43:39.000Z

def login(agent, user, password)
    agent.get(LOGIN_PATH) do |page|
      puts "Loaded login page."
        login_form = page.form('login')
        login_form['login:loginUsernameField'] = user
        login_form['login:password'] = password
 
    puts "Sent login information."
        page = agent.submit(login_form, login_form.buttons.first)
        raise "Login incorrect!" if page.title().match('Sign In')
    puts "Login successful!"
        return page
  end
end

def each_activity(agent)
    start = 0
    while true do
        res = agent.get(QUERY_PATH % start)
        activities = JSON.parse(res.content)['results']
        return if activities['activities'].length == 0

        activities['activities'].each do |activity|
            yield activity['activity']['activityId']
            start += 1
            # return
        end
    end
end

def activity_header(activity)
    id = activity.elements["Id"].text
    totalSeconds = 0.0
    totalDistance = 0.0
    totalCalories = 0.0
    startTime = nil
    activity.elements.each("Lap") do |lap|
        totalSeconds += lap.elements["TotalTimeSeconds"].text.to_f
        totalDistance += lap.elements["DistanceMeters"].text.to_f
        totalCalories += lap.elements["Calories"].text.to_f
        startTime = lap.attributes['StartTime'] if startTime.nil?
    end
    return startTime, totalSeconds, totalDistance, totalCalories
end

def spline_every_10(time, distance, hr, totalDistance)
    distance_spline = SimpleSpliner.new time, distance
    hr_spline = SimpleSpliner.new time, hr

    t = 10000
    d = []
    h = []

    while t <= time.last
        d.push distance_spline[t]
        h.push hr_spline[t]
        t += 10000
    end
    unless (d.last * 1000).to_i == (totalDistance * 1000).to_i
        d.push totalDistance
        h.push h.last
    end
    return d, h
end

def activity_detail(startTime, totalDistance, activity)
    start = Time.parse(startTime)
    time = []
    distance = []
    hr = []
    tp =[]
    activity.elements.each("Lap") do |lap|
        lap.elements.each("Track/Trackpoint") do |point|
            point_time = Time.parse(point.elements['Time'].text)
            time.push(((point_time - start) * 1000).to_i)
            distance.push(point.elements['DistanceMeters'].text.to_f)
            hr_elem = point.elements['HeartRateBpm/Value']
            if hr_elem.nil? then
                if hr.length == 0 then
                    hr.push 0
                else
                    hr.push hr.last
                end
            else
                hr.push(hr_elem.text.to_f)
            end
            pos_elem = point.elements['Position']
            unless pos_elem.nil? then
                lat = pos_elem.elements['LatitudeDegrees'].text
                lon = pos_elem.elements['LongitudeDegrees'].text
                alt = point.elements['AltitudeMeters'].text
                tp.push [point.elements['Time'].text, lat, lon, alt]
            end
        end
    end
    puts "tackpoint count: #{tp.length}"
    d, h = spline_every_10(time, distance, hr, totalDistance)
    puts "d.last: #{d.last}"
    puts "h.last: #{h.last}"
    return d, h, tp
end

def parse_tcx(tcx)
    doc = REXML::Document.new(tcx)
    if doc.elements["TrainingCenterDatabase"].nil? then
        puts "tcx invalid"
        return
    end
    doc.elements.each("TrainingCenterDatabase/Activities/Activity") do |activity|
        if activity.attributes['Sport'] == 'Running' then
            startTime, totalSeconds, totalDistance, totalCalories = activity_header(activity)
            puts "start: #{startTime}"
            puts "seconds: #{totalSeconds}"
            puts "distance: #{totalDistance}"
            puts "calories: #{totalCalories}"
            distance, hr, trackpoints = activity_detail(startTime, totalDistance, activity)
        end
    end
end

def get_tcx(agent, id)
    res = agent.get(TCX_PATH % id)
    parse_tcx(res.content)
end

# parse_tcx(File.new('/Users/hu/Downloads/activity_427027236.tcx'))
remote = true

if remote then
    agent = Mechanize.new
    login(agent, 'hhhhtj', 'deqrpl')

    each_activity(agent) do |id|
        puts '-' * 40
        puts "downloading activity #{id}"
        get_tcx(agent, id)
    end
end