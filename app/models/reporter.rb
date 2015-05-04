class Reporter

  def create_payload(action_group)
    values = action_group.values.flatten
    card_name = values.first[:data]['card']['name']
    card_link = "[#{card_name}](https://trello.com/c/#{values.first[:data]['card']['shortLink']})"
    completed = values.map{ |x| x[:completed] }.inject{|m, o| m or o}

    actors, commenters = [], []
    closer = nil

    values.each do |x|
      if x[:type] == 'addMemberToCard'
        actors << "@#{x[:member]['username']}"
      else
        actors << "@#{x[:memberCreator]['username']}"
        closer = actors.last if x[:data].fetch('listAfter', {}).fetch('name', nil) == 'Done'
      end

      commenters << "@#{x[:memberCreator]['username']}" if x[:type] == 'commentCard'
    end
    actors.uniq!
    commenters.uniq!

    content = generate_content(
                actors: actors,
                commenters: commenters,
                card_reference: card_name,
                completed: completed,
                closer: closer)
    reason = generate_reason(
                actors: actors,
                commenters: commenters,
                card_link: card_link,
                completed: completed)

    {
      upsert_key: values.first[:data]['card']['id'],
      content: content,
      score: completed ? 1.0 : 0.5,
      type: completed ? 'Completed card' : 'High activity card',
      occurred_at: values.map{|x| x[:date]}.max
    }
  end

  def generate_reason(actors:, commenters:, card_link:, completed:)
    if completed
      "Trello card completed by #{actors.to_sentence}"
    else
      "#{commenters.to_sentence} commented on Trello card"
    end
  end

  def generate_content(actors:, commenters:, card_reference:, completed:, closer: nil)
    deduped_participants = (actors | commenters) - [closer]
    if completed && closer
      "#{closer} closed \"#{card_reference}\" #{deduped_participants.empty? ? nil : "with involvement from #{deduped_participants.to_sentence}"}"
    else
      "#{(actors | commenters).to_sentence} were active on \"#{card_reference}\""
    end
  end

  def report(since:, before:, retries: 0)
    begin
      trello = TrelloFetcher.new
      boards = trello.boards

      resource = RestClient::Resource.new(
                    ENV['ASSEMBLY_TITAN_ENDPOINT'],
                    ENV['USERNAME'],
                    ENV['PASSWORD']
                  )

      actions = []
      boards.each do |board|
        actions += trello.actions(board_id: board.fetch('id'), since: since, before: before)
      end

      grouped_actions = trello.group_by_card(actions)
      # show all closed cards
      closed_cards = trello.closed_cards(grouped_actions)
      # show high activity cards
      high_activity_cards = trello.high_activity_cards(grouped_actions)

      payloads = [closed_cards, high_activity_cards]
                    .flatten
                    .uniq
                    .map{|x| create_payload(x)}

      puts "posting #{payloads.length} payloads"
      payloads.each do |payload|
        puts payload
        resource.post(payload)
      end
    rescue Exception => e
      puts "Error occurred: #{e}"
      if (retries -= 1) < 0
        raise e
      else
        report(since: since, before: before, retries: retries)
      end
    end
  end

  def titan_report(since:, before:, retries: 0)
    begin
      trello = TrelloFetcher.new
      board = trello.boards.select{|board| board.fetch('name') == 'Titan'}.first
      actions = trello.actions(board_id: board.fetch('id'), since: since, before: before)

      # currently only processes Done cards
      actions.each do |action|
        payload = TitanPayload.new.process(action)
        TitanDispatcher.publish!(payload) unless payload.nil?
      end

    rescue Exception => e
      puts "Error occurred: #{e}"
      if (retries -= 1) < 0
        raise e
      else
        report(since: since, before: before, retries: retries)
      end
    end
  end
end
