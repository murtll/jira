module Scenarios
  ##
  # Prepare released repos and write to file
  class PrepareAllRepoList
    def run(release_skip = false)
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      LOGGER.info("Start work with #{issue.key}")
      if issue.fields['issuetype']['name'].include?('Release') || release_skip
        result = ''
        issue.branches.each do |branch|
          result += ",#{branch.repo_slug}"
        end
        result = result[1..] # delete first comma
        LOGGER.info("Find repos: #{result}")


        Ott::Helpers.export_to_file(result, 'repo_list.txt')
        Ott::Helpers.export_to_file("RELEASE_NAME=#{issue.summary}", 'release_name')
      else
        LOGGER.warn("Ticket #{issue.key} not a release ticket")
      end
      result
    end
  end
end
