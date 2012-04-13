module ApplicationHelper

  def partial(part)
    render part
  end

  def random_tagline
    tags = ['fast-version-control',
     'everything-is-local',
     'distributed-even-if-your-workflow-isnt',
     'local-branching-on-the-cheap',
     'not-your-daddys-version-control',
     'distributed-is-the-new-centralized' ]
    mtag = tags[rand(tags.length)]
    "<em>--</em>#{mtag}"
  end

  def latest_version
    Version.latest_version.name
  end

  def latest_release_date
    '(' + Version.latest_version.committed.strftime("%Y-%m-%d") + ')'
  end

end
