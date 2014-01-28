require 'rubygems'
require 'mechanize'
require 'json'

require './activity'
require './logging'

class Connect
    include Logging

    BASE_PATH = 'https://connect.garmin.com'
    BASE_URI = URI(BASE_PATH)
    LOGIN_PATH = "#{BASE_PATH}/signin/"
    QUERY_PATH = "#{BASE_PATH}/proxy/activity-search-service-1.2/json/activities?"
    QUERY_TIME_PATH = "#{BASE_PATH}/proxy/activity-search-service-1.2/json/activities?activitySummaryBeginTimestampGmt>%s&"
    TCX_PATH = "#{BASE_PATH}/proxy/activity-service-1.0/tcx/activity/%d?full=true"

    def initialize(user, pass)
        @agent = Mechanize.new { |a| a.ssl_version, a.verify_mode = 'SSLv3', OpenSSL::SSL::VERIFY_NONE }
        login(user, pass)    
    end

    def login(user, password)
        logger.info "loading Garmin login page."
        @agent.get(LOGIN_PATH) do |page|
            login_form = page.form('login')
            login_form['login:loginUsernameField'] = user
            login_form['login:password'] = password

            logger.info "sent Garmin login information."
            page = @agent.submit(login_form, login_form.buttons.first)
            if page.title().match('Sign In') then
                logger.error "cannot login garmin"
                raise "Login Garmin incorrect!" 
            end
            logger.info "login Garmin successful!"
            return page
        end
    end

    def each_activity_with_query(query)
        query = query + "start=%d"
        start = 0
        while true do
            logger.info "querying garmin #{query % start}"
            res = @agent.get(query % start)
            activities = JSON.parse(res.content)['results']['activities']
            logger.info "retrieved #{activities.length} activities"
            return if activities.length == 0

            activities.each do |activity|
                yield activity['activity']['activityId']
                start += 1
            end
        end
    end

    def each_activity()
        each_activity_with_query(QUERY_PATH) do |x|
            yield x
        end
    end

    def each_activity_after(time)
        each_activity_with_query(QUERY_TIME_PATH % time) do |x|
            yield x
        end
    end

    def get_tcx(id)
        res = @agent.get(TCX_PATH % id)
        return res.content
    end

end