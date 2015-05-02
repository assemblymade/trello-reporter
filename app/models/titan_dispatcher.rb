class TitanDispatcher
  def self.publish!(payload)
    return unless payload
    puts "posting payload: #{payload}"
    resource =  RestClient::Resource.new(
                  ENV['ASSEMBLY_TITAN_ENDPOINT'],
                  ENV['USERNAME'],
                  ENV['PASSWORD']
                )
    resource.post(payload)
  end

  # delete all highlights from this reporter
  def self.delete_all!
    RestClient::Resource.new(
      "#{ENV['TITAN_ENDPOINT']}/reporter",
      ENV['USERNAME'],
      ENV['PASSWORD']
    ).delete
  end
end
