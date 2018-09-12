module Rucicka
  MQTT_IP = '127.0.0.1'.freeze
  MQTT_TOPIC_IN = 'rucicka/move'.freeze
  MQTT_TOPIC_OUT = 'rucicka/status'.freeze

  M = 14.60500 # shoulder to elbow, 5,75" = 14.60500 cm = 0,14605 m
  N = 18.7325 # elbow to wrist, 7,375" = 18.7325 cm = 0,187325 m

  class Array
    def chr
      map(&:chr)
    end
  end

  class Numeric
    def radians
      (self * Math::PI) / 180
    end

    def degrees
      (self * 180) / Math::PI
    end
  end

  module OS
    def self.windows?
      (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    end

    def self.mac?
      (/darwin/ =~ RUBY_PLATFORM) != nil
    end

    def self.unix?
      !OS.windows?
    end

    def self.linux?
      OS.unix? && !OS.mac?
    end
  end
end
