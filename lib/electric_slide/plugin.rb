# encoding: utf-8
require 'adhearsion'

class ElectricSlide
  class Plugin < Adhearsion::Plugin
    init do
      logger.info 'ElectricSlide plugin loaded.'
    end
  end
end
