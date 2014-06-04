require 'rexml/document'
require 'time'

require './simplespliner'
require './logging'

class Activity
    include Logging

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
        # unless (d.last * 1000).to_i == (totalDistance * 1000).to_i
        #     d.push totalDistance
        #     h.push h.last
        # end
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
        d, h = spline_every_10(time, distance, hr, totalDistance)
        return d, h, tp
    end

    def parse_tcx(tcx)
        logger.info "parsing tcx file"
        doc = REXML::Document.new(tcx)
        if doc.elements["TrainingCenterDatabase"].nil? then
            logger.warn "tcx invalid"
            return
        end
        doc.elements.each("TrainingCenterDatabase/Activities/Activity") do |activity|
            if activity.attributes['Sport'] == 'Running' then
                startTime, totalSeconds, totalDistance, totalCalories = activity_header(activity)
                logger.info "start: #{startTime}"
                logger.info "seconds: #{totalSeconds}"
                logger.info "distance: #{totalDistance}"
                logger.info "calories: #{totalCalories}"
                distance, hr, trackpoints = activity_detail(startTime, totalDistance, activity)
                logger.info "distance samples: #{distance.length}"
                logger.info "heart rate samples: #{hr.length}"
                logger.info "trackpoint samples: #{trackpoints.length}"
                return [startTime, totalSeconds, totalDistance, totalCalories, distance, hr, trackpoints]
            end
        end
    end

    def parse_tcx_header(tcx)
        logger.info "parsing tcx file"
        doc = REXML::Document.new(tcx)
        if doc.elements["TrainingCenterDatabase"].nil? then
            logger.warn "tcx invalid"
            return
        end
        doc.elements.each("TrainingCenterDatabase/Activities/Activity") do |activity|
            if activity.attributes['Sport'] == 'Running' then
                startTime, totalSeconds, totalDistance, totalCalories = activity_header(activity)
                return [startTime, totalSeconds, totalDistance, totalCalories]
            end
        end
    end

end