# encoding: utf-8
class Agent
  attr_accessor :id, :address, :presence

  # @param [Hash] opts Agent parameters
  # @option opts [String] :id The Agent's ID
  # @option opts [String] :address The Agent's contact address
  # @option opts [String] :presence The Agent's current presence
  def initialize(opts = {})
    @id = opts[:id]
    @address = opts[:address]
    @presence = opts[:presence]
  end

end

