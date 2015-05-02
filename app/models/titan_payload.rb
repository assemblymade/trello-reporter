class TitanPayload

  def process(action)
    type = action['type']
    puts "processing #{type} action"
    case type
    when 'updateCard'
      if action['data'].fetch('listAfter', {}).fetch('name', nil) == 'Done'
        completed_card(action)
      end
    end
  end

  def get_actors(actions)
    actions.map do |action|
      [
        action['memberCreator']['username'],
        action.fetch('member', {}).fetch('username', nil)
      ]
    end.flatten.compact.uniq
  end

  def completed_card(action)
    closer = action['memberCreator']['username']
    card_actions = TrelloFetcher.new.card_actions(card_id: action['card']['id'])
    actors = get_actors(card_actions)
    content = action['data']['card']['name']

    {
      upsert_key: action['data']['card']['id'],
      label: "@#{closer} moved a Trello card to \"Done\"",
      content: content,
      score: 1.0,
      category: 'Completed card',
      occurred_at: action['date'],
      actors: actors
    }
  end

end
