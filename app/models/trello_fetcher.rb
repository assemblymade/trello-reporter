require 'active_support/all'
require 'restclient'
require 'pp'

class TrelloFetcher

  def boards
    get('/organizations/assembly4/boards')
  end

  def actions(board_id:, since:, before: Time.now)
    actions = get("/boards/#{board_id}/actions", {
      filter: [ 'addAttachmentToCard',
                'addChecklistToCard',
                'addMemberToCard',
                'commentCard',
                'createCard',
                'updateCard'].join(','),
      limit: 1000,
      since: since,
      before: before
    })
  end

  def card_actions(card_id:)
    get("/cards/#{card_id}/actions", {
      filter: [ 'addAttachmentToCard',
                'addChecklistToCard',
                'addMemberToCard',
                'commentCard',
                'createCard',
                'updateCard'].join(','),
      limit: 1000,
    })
  end

  def cards_with_actions(board_id:, since:, before: Time.now)
    # default filter is visible cards
    cards = get("/boards/#{board_id}/cards", {
      actions: ['addAttachmentToCard',
                'addChecklistToCard',
                'addMemberToCard',
                'commentCard',
                'createCard',
                'updateCard'].join(',')
      })
    cards.select{|card| card['dateLastActivity'] >= since && card['dateLastActivity'] <= Time.now}
  end

  def group_by_card(actions)
    actions.group_by{|x| x['data']['card']['id']}
           .map do |a|
             comment_count = a[1].select{|x| x['type'] == 'commentCard'}.count
             completed = false
            {
              "#{a[1].first['data']['card']['name']}" => a[1].map do |x|
                {
                  type: x['type'],
                  data: x['data'],
                  memberCreator: x['memberCreator'],
                  member: x.fetch('member', nil),
                  commentCount: comment_count,
                  completed: completed ||= x['data'].fetch('listAfter', {})
                                                    .fetch('name', nil) == 'Done',
                  date: Time.parse(x['date'])
                }
              end
            }
    end
  end

  def closed_cards(grouped_actions)
    grouped_actions.select{|action| action.values.flatten.map{|x| x[:completed]}.inject{|m,o| m or o}}
  end

  def high_activity_cards(grouped_actions)
    mean_action_count = grouped_actions.map{|x| x.values.flatten.count}.inject(&:+) / grouped_actions.count.to_f
    std_dev_actions = Math.sqrt (grouped_actions.map{|x| x.values.flatten.count}.inject(0) { |m, i| m + (i-mean_action_count)**2 } / (grouped_actions.count - 1).to_f)
    grouped_actions.select{|action| action.values.flatten.count > mean_action_count + std_dev_actions/(ENV['SIGNIFICANCE_FACTOR'].to_f || 3.0)}
  end

  def post(path, params={})
    url = File.join("https://api.trello.com/1", path)
    response = RestClient.post(url, params: {key: ENV['TRELLO_KEY'], token: ENV['TRELLO_TOKEN']}.merge(params))
    JSON.parse(response)
  end

  def get(path, params={})
    url = File.join("https://trello.com/1", path)
    response = RestClient.get(url, params: {key: ENV['TRELLO_KEY'], token: ENV['TRELLO_TOKEN']}.merge(params))
    JSON.parse(response)
  end

end

# calculate avg activity per day
# poll every 12 hr and update avg activity per day (exponential moving average)

# cards that have more actions than the average action
# high_action_cards = grouped_actions.select{|action| action.values.flatten.count > 2}

# filter action groups by ones which were moved to 'Done'


# class TrelloActionFormatter
#   def initialize(action)
#     @action = action
#   end
#
#   def format
#     action_type = @action.fetch('type', nil)
#     send(action_type.underscore)
#   end
#
#   def update_card
#     card_link = "[#{@action['data']['card']['name']}](https://trello.com/c/#{@action['data']['card']['shortLink']})"
#     if data.fetch('listAfter', nil) == 'Done'
#       # changed lists
#       # {
#       #   content: "@#{@action['memberCreator']['username']} completed [#{@action['data']['card']['name']}](https://trello.com/c/#{@action['data']['card']['shortLink']})",
#       #   label: nil,
#       #   reason: nil
#       # }
#       "@#{@action['memberCreator']['username']} completed #{card_link}"
#     elsif data.fetch('closed', nil)
#       # archived
#       "@#{@action['memberCreator']['username']} archived #{card_link}"
#     end
#   end
#
#   def comment_card
#
#   end
# end
# puts actions
#
# actions.each do |action|
#   puts "#{action['memberCreator']['username']} #{action['type']} #{action['date']}\n #{action['data']['card']['name']}"
# end

# Highlight { content, label, reason }

# Card moved from list to list
# type: updateCard
# {
#   "data" => {
#     "listAfter" => {
#         "name" => "Doing", "id" => "54e55bc83122d82a43070c4d"
#     }, "listBefore" => {
#         "name" => "Todo", "id" => "54e55bd0f7b2bf0b7568458f"
#     }
# }

# Card commented on
# type: commentCard
# {
#   "data" => {
#     "text" => {
#         "text of the comment"
#     }
# }

# Add attachment to card
# type: addAttachmentToCard
# {
#   "data" => {
#     "board" => {
#         "shortLink" => "uMRthsOn", "name" => "Platform", "id" => "54e55b780d9e3716a7dbdf04"
#     }, "card" => {
#         "shortLink" => "tKSBAJTX", "idShort" => 248, "name" => "Group related activities in single stories", "id" => "5536b602f6c8c1593daecb51"
#     }, "attachment" => {
#         "previewUrl2x" => "https://trello-attachments.s3.amazonaws.com/5536b602f6c8c1593daecb51/284x425/aa3a65517dc677ce6339eeaf2d6cb2db/Screen_Shot_2015-04-21_at_1.41.42_PM.png",
#         "previewUrl" => "https://trello-attachments.s3.amazonaws.com/5536b602f6c8c1593daecb51/284x425/aa3a65517dc677ce6339eeaf2d6cb2db/Screen_Shot_2015-04-21_at_1.41.42_PM.png",
#         "url" => "https://trello-attachments.s3.amazonaws.com/5536b602f6c8c1593daecb51/284x425/aa3a65517dc677ce6339eeaf2d6cb2db/Screen_Shot_2015-04-21_at_1.41.42_PM.png",
#         "name" => "Screen Shot 2015-04-21 at 1.41.42 PM.png", "id" => "5536b619e39a32713d767f0c"
#     }
# }

# archived card
# {
#   "data" => {
#     "closed" => {true}
# }


# You commented a bunch on this card:
#   "Trello integration experiment"
# => I did lots of work on [Trello integration experiment](https://trello.com...)

# You were assigned to
#   "Slack conversation exploration"
# => I did lots of work on [Trello integration experiment](https://trello.com...)

# Moved 27 cards in Platform
#   [Platform](...)

# Mixpanel:
# "Signup" were out of this world
#   [img] 30 days of signups


# board object
# [{
#     "id": "4eea4ffc91e31d1746000046",
#     "closed": false,
#     "dateLastActivity": null,
#     "dateLastView": null,
#     "desc": "This board is used in the API examples",
#     "descData": null,
#     "idOrganization": "4efe2c2f2e1efe7a4c0002c9",
#     "invitations": [],
#     "invited": false,
#     "labelNames": {
#         "green": "",
#         "yellow": "Low Priority",
#         "orange": "Medium Priority",
#         "red": "High Priority",
#         "purple": "",
#         "blue": "",
#         "sky": "",
#         "lime": "",
#         "pink": "",
#         "black": ""
#     },
#     "memberships": [{
#         "id": "4eea4ffc91e31d174600004d",
#         "idMember": "4ee7deffe582acdec80000ac",
#         "memberType": "admin",
#         "unconfirmed": false
#     }, {
#         "id": "4eea507991e31d17460000fc",
#         "idMember": "4ee7df1be582acdec80000ae",
#         "memberType": "normal",
#         "unconfirmed": false
#     }, {
#         "id": "4eea50bc91e31d174600016d",
#         "idMember": "4ee7df74e582acdec80000b6",
#         "memberType": "normal",
#         "unconfirmed": false
#     }],
#     "name": "Example Board",
#     "pinned": false,
#     "powerUps": [],
#     "prefs": {
#         "permissionLevel": "public",
#         "voting": "members",
#         "comments": "members",
#         "invitations": "members",
#         "selfJoin": false,
#         "cardCovers": true,
#         "background": "blue",
#         "backgroundColor": "#0079BF",
#         "backgroundImage": null,
#         "backgroundImageScaled": null,
#         "backgroundTile": false,
#         "backgroundBrightness": "unknown",
#         "canBePublic": true,
#         "canBeOrg": true,
#         "canBePrivate": true,
#         "canInvite": true
#     },
#     "shortLink": "OXiBYZoj",
#     "shortUrl": "https://trello.com/b/OXiBYZoj",
#     "starred": null,
#     "subscribed": null,
#     "url": "https://trello.com/b/OXiBYZoj/example-board"
# }]

# sample ACTIONS
# [{
#     "id": "4eea523791e31d17460002a0",
#     "data": {
#         "card": {
#             "id": "4eea522c91e31d174600027e",
#             "name": "Figure out how to read a user's board list"
#         },
#         "board": {
#             "id": "4eea4ffc91e31d1746000046",
#             "name": "Example Board"
#         },
#         "idMember": "4ee7df74e582acdec80000b6"
#     },
#     "date": "2011-12-15T20:01:59.688Z",
#     "idMemberCreator": "4ee7deffe582acdec80000ac",
#     "type": "addMemberToCard",
#     "member": {
#         "id": "4ee7df74e582acdec80000b6",
#         "avatarHash": "c9903e2464563d83e38df3afd685dc6c",
#         "fullName": "David Tester",
#         "initials": "DT",
#         "username": "davidtester"
#     },
#     "memberCreator": {
#         "id": "4ee7deffe582acdec80000ac",
#         "avatarHash": null,
#         "fullName": "Joe Tester",
#         "initials": "JT",
#         "username": "joetester"
#     }
# }]
