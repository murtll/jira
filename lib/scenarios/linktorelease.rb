module Scenarios
  ##
  # Link tickets to release issue
  class LinkToRelease
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}", max_results: 100)
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.error "Error in JIRA with the search by filter #{filter}: #{error_message}"
      []
    end

    def run
      params = SimpleConfig.release

      unless params
        LOGGER.error 'No Release params in ENV'
        exit
      end

      filter_config = JSON.parse(ENV['RELEASE_FILTER'])
      client = JIRA::Client.new SimpleConfig.jira.to_h
      release_issue = client.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(release_issue.key).to_s

      project_name = release_issue.fields['project']['key']
      release_name = release_issue.fields['summary'].upcase
      release_issue_number = release_issue.key
      components = release_issue.fields['components']
      component = if components.count > 1
                    LOGGER.error "Found more than 1 components: #{components.count} Should be only 1"
                    release_issue.post_comment <<-BODY
                      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
                        Релиз не должен содержать больше чем 1 компонент (x)
                      {panel}
                    BODY
                    exit
                  else
                    components
                  end

      # Check project exist in filter_config
      if filter_config[project_name].nil?
        message = "I can't work with project '#{project_name.upcase}'. Pls, contact administrator to feedback"
        release_issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            #{message} (x)
          {panel}
        BODY
        LOGGER.error message
        raise 'Project not found'
      end

      LOGGER.info "Linking tickets to release '#{release_name}'"

      # Check release type
      release_type = if %w[_BE_ _BE BE_ BE].any? { |str| release_name.include?(str) }
                       'backend'
                     elsif %w[_FE_ _FE FE_ FE].any? { |str| release_name.include?(str) }
                       'frontend'
                     else
                       'common'
                     end

      LOGGER.info "Release type: #{release_type}"
      release_filter = filter_config[project_name][release_type]
      release_filter = "#{release_filter} AND component = #{component.first['name']}" unless component.empty?

      # Check release filter
      if release_filter.nil? || release_filter.empty?
        message = "I don't find release filter for jira project: '#{project_name.upcase}' and release_type: #{release_type}"
        release_issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            #{message} (x)
          {panel}
        BODY
        LOGGER.error message
        raise 'Release_filter not found'
      end

      LOGGER.info "Release filter: #{release_filter}"

      issues = release_filter && find_by_filter(client.Issue, release_filter)

      # Check issues not empty
      if issues.empty?
        LOGGER.warn "Release filter: #{release_filter} doesn't contain any issues"
        release_issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            Фильтр #{release_filter} не содержит задач (x)
          {panel}
        BODY
        exit
      else
        LOGGER.info "Release filter contains: #{issues.count} tasks"
      end

      # Message about count of release candidate issues
      release_issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            Тикетов будет прилинковано: #{issues.count} (!)
          {panel}
      BODY

      issues.each do |issue|
        issue.link(release_issue_number)
      end

      unless %w[ADR IOS].any? { |p| release_issue_number.include? p }
        release_labels = []
        issues.each do |issue|
          issue.related['branches'].each do |branch|
            release_labels << branch['repository']['name'].to_s
          end
        end

        release_labels.uniq!

        LOGGER.info "Add labels: #{release_labels} to release #{release_name}"
        release_issue.save(fields: { labels: release_labels })
        release_issue.fetch
      end

      # Message about done
      release_issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            Формирование релиза закончено (/)
          {panel}
      BODY
    end
  end
end
