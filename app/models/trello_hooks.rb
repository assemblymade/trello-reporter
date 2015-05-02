class TrelloHooks
  def boards
    get('/organizations/assembly4/boards')
  end

  def subscribe_webhooks(board_names:)
    boards = self.boards.select{ |board| board_names.include?(board.fetch('name')) }

    boards.each do |board|
      puts "subscribing to #{board.fetch('name')}"
      post({
        description: "#{board.fetch('name')}",
        callbackURL: "#{Rails.application.routes.url_helpers.webhook_receive_url(host: ENV['CALLBACK_HOST'])}?org=assembly",
        idModel: board.fetch('id'),
      })
    end
  end

  def post(params={})
    response = RestClient.post("https://api.trello.com/1/tokens/#{ENV['TRELLO_TOKEN']}/webhooks/?key=#{ENV['TRELLO_KEY']}", params)
    JSON.parse(response)
  end

  def get(path, params={})
    url = File.join("https://api.trello.com/1", path)
    response = RestClient.get(url, params: {key: ENV['TRELLO_KEY'], token: ENV['TRELLO_TOKEN']}.merge(params))
    JSON.parse(response)
  end
end
