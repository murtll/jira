module Scenarios
  ##
  # Link tickets to release issue
  class LinkToMobileRelease
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}", max_results: 100)
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.error "Error in JIRA with the search by filter #{filter}: #{error_message}"
      []
    end

    @android_app_filter = {}
    @ios_app_filter = {}

    def run
      params = SimpleConfig.release

      unless params
        LOGGER.error 'No Release params in ENV'
        exit
      end

      # Получаем данные тикета
      client = JIRA::Client.new SimpleConfig.jira.to_h
      isss = client.Issue
      issue = client.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s

      # if issue.key.include('AND')
      #   app_filter = android_app_filter
      # end

      # Получаем значения поля apps из релиза
      apps = issue.fields['customfield_12166']['value']

      # Проверяем есть ли релизы AND/IOS с такими значениями и не закрытые
      # apps_filter = {
      #   b2c_ott: ,
      # b2c_avia: ,
      # b2c_railways: ,
      # b2b_ott: ,
      # b2c_kz: ,
      # b2c_solar: ,
      # b2c_ott_huawei: ,
      # }


      created_releases = find_by_filter(isss, "issuetype = Release and status != Done and \"App[Dropdown]\" = b2c_ott")
      # created_releases = issue.jql("issuetype = Release and status != Done and \"App[Dropdown]\" = b2c_ott", max_results: 100)
      puts created_releases.to_json

      # # собираем список
      # issue_links.each do |item|
      #   deployes_issues.append(item['outwardIssue']['key']) if item['type']['outward'] == 'deployes'
      # end

      # arr_ticket_and_apps = []
      
      # deployes_issues.each_with_index { |find_issues_tiket, index|
      #
      #   issue = client.Issue.find(find_issues_tiket)
      #
      #   puts issue.fields['customfield_12207'][0]['value']
      # }
    end
  end
end