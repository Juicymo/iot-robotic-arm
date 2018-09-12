require 'mqtt'
require_relative 'lib'
require_relative 'rucicka'

module Rucicka
  class Client
    include Lib

    def initialize
      @client = MQTT::Client.connect(MQTT_IP)
      define_presents
      send(mqtt_format(@presets[:park]))
      p coords_format(@coords)
    end


    private

    def send(coords)
      @client.publish(MQTT_TOPIC_IN, coords, false)
      _, message = @client.get(MQTT_TOPIC_OUT)
      @coords = mqtt_parse(message)
    end
  end
end