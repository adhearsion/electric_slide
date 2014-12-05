# encoding: utf-8
class Agent
  attr_accessor :id, :address, :presence, :connect_callback, :disconnect_callback

  # @param [Hash] opts Agent parameters
  # @option opts [String] :id The Agent's ID
  # @option opts [String] :address The Agent's contact address
  # @option opts [Symbol] :presence The Agent's current presence. Must be one of :available, :on_call, :away, :offline
  def initialize(opts = {})
    @id = opts[:id]
    @address = opts[:address]
    @presence = opts[:presence]
  end

end

