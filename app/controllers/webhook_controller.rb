class WebhookController < ApplicationController
  def receive
    if request.post?
      payload = TitanPayload.new.process(JSON.parse(request.raw_post)['action'])
      TitanDispatcher.publish!(payload)
      render json: payload
    else
      render text: 'Please POST to this route'
    end
  end
end
